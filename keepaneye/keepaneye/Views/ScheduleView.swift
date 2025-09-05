import SwiftUI

struct ScheduleView: View {
    @State private var selectedDate = Date()
    @State private var selectedChild: Child?
    @State private var schedules: [Schedule] = []
    @State private var showingAddSchedule = false
    @State private var showingDeleteAlert = false
    @State private var scheduleToDelete: Schedule?
    @State private var showingDatePickerSheet = false
    @State private var showingDayPlanner = false
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content area
                if let child = selectedChild {
                    VStack(spacing: 0) {
                        // Child name subtitle
                        HStack {
                            Spacer()
                            Text(child.fullName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 5)
                        .background(Color(.systemBackground))
                
                        ScheduleContentView(
                            child: child,
                            selectedDate: $selectedDate,
                            schedules: schedules,
                            onDeleteSchedule: { schedule in
                                scheduleToDelete = schedule
                                showingDeleteAlert = true
                            },
                            onUpdateSchedules: refreshSchedules,
                            hasTemplates: !dataManager.getScheduleTemplates(for: child.id).isEmpty,
                            onShowCalendar: { showingDatePickerSheet = true },
                            onShowDayPlanner: { showingDayPlanner = true }
                        )
                    }
                } else {
                    // Child selection content - full screen
                    ChildSelectionView(selectedChild: $selectedChild)
                }
            }
            .navigationTitle(selectedChild == nil ? "" : "Daily Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedChild != nil {
                        Button(action: { selectedChild = nil }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedChild != nil {
                        Menu {
                            Button(action: { showingDayPlanner = true }) {
                                Label("Activity Planner", systemImage: "calendar.badge.plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDatePickerSheet) {
                NavigationView {
                    VStack {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .padding()
                        Spacer()
                    }
                    .navigationTitle("Select Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingDatePickerSheet = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDayPlanner) {
                if let child = selectedChild {
                    DayPlannerView(
                        child: child, 
                        date: selectedDate,
                        onSave: {
                            // Force fresh after saving from planner
                            refreshSchedules()
                        }
                    )
                }
            }
            .alert("Delete Schedule", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let schedule = scheduleToDelete {
                        deleteSchedule(schedule)
                    }
                }
                Button("Cancel", role: .cancel) {
                    scheduleToDelete = nil
                }
            } message: {
                if let schedule = scheduleToDelete {
                    Text("Are you sure you want to delete '\(schedule.title)'?")
                }
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                print("[Schedule] Date changed: \(oldValue) -> \(newValue)")
                loadSchedules()
            }
            .onChange(of: selectedChild) { oldValue, newValue in
                print("[Schedule] selectedChild changed: \(oldValue?.fullName ?? "nil") -> \(newValue?.fullName ?? "nil")")
                loadSchedules()
            }
            .onAppear {
                print("[Schedule] onAppear - selectedChild=\(selectedChild?.fullName ?? "nil")")
                loadSchedules()
            }
        }
    }
    
    private func loadSchedules() {
        guard let child = selectedChild else { 
            print("[Schedule] loadSchedules skipped - no selectedChild")
            return 
        }
        
        Task {
            do {
                // Always fetch fresh schedules (no auto-generation)
                let fetchedSchedules = try await APIClient.shared.getSchedulesFresh(
                    childId: child.id,
                    date: selectedDate
                )
                
                await MainActor.run {
                    schedules = fetchedSchedules
                    print("[Schedule] loadSchedules - count=\(schedules.count), child=\(child.fullName)")
                }
                // No auto-generation anymore
            } catch {
                print("❌ Failed to load schedules: \(error)")
                // Fallback to local data
                await MainActor.run {
                    schedules = dataManager.getSchedules(for: child.id, on: selectedDate)
                }
            }
        }
    }
    
    private func refreshSchedules() {
        guard let child = selectedChild else { return }
        
        Task {
            do {
                // Fetch fresh schedules from backend
                let newSchedules = try await APIClient.shared.getSchedulesFresh(
                    childId: child.id,
                    date: selectedDate
                )
                
                await MainActor.run {
                    print("🔄 Refreshing schedules: \(schedules.count) → \(newSchedules.count)")
                    
                    // Debug: Print all schedules to see what we have
                    for (index, schedule) in newSchedules.enumerated() {
                        print("   [\(index)] \(schedule.title) - ID: \(schedule.id) - Modified: \(schedule.hasBeenModified) - Template: \(schedule.templateId ?? "none")")
                    }
                    
                    schedules = newSchedules
                }
            } catch {
                print("❌ Failed to refresh schedules: \(error)")
            }
        }
    }
    
    private func deleteSchedule(_ schedule: Schedule) {
        Task {
            do {
                try await APIClient.shared.deleteSchedule(id: schedule.id)
                // After deletion, fetch fresh
                await refreshSchedules()
            } catch {
                print("❌ Failed to delete schedule: \(error)")
            }
        }
    }
}

struct ScheduleContentView: View {
    let child: Child
    @Binding var selectedDate: Date
    let schedules: [Schedule]
    let onDeleteSchedule: (Schedule) -> Void
    let onUpdateSchedules: () -> Void
    let hasTemplates: Bool
    let onShowCalendar: () -> Void
    let onShowDayPlanner: () -> Void
    @State private var showingAddCard = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Date header with controls
            VStack(spacing: 15) {
                HStack {
                    Button(action: { adjustDay(-1) }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(action: { onShowCalendar() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: { adjustDay(1) }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 10)
            .padding(.bottom, 5)
            .background(Color(.systemBackground))
            
            ScrollView {
                LazyVStack(spacing: 15) {
                    if schedules.isEmpty {
                        VStack(spacing: 20) {
                            EmptyScheduleView(date: selectedDate)
                            
                            if hasTemplates {
                                Button(action: {
                                    showingAddCard = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Adhoc Event")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }
                            } else {
                                Button(action: {
                                    onShowDayPlanner()
                                }) {
                                    HStack {
                                        Image(systemName: "calendar.badge.plus")
                                        Text("Activity Planner")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    } else {
                        ForEach(schedules) { schedule in
                            ScheduleCard(
                                schedule: schedule,
                                onDelete: onDeleteSchedule,
                                onUpdate: onUpdateSchedules
                            )
                        }
                        
                        // Add button at the bottom
                        Button(action: {
                            showingAddCard = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Adhoc Event")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAddCard) {
            InlineAddScheduleView(
                child: child,
                date: selectedDate,
                onScheduleAdded: {
                    onUpdateSchedules()
                    showingAddCard = false
                }
            )
        }
    }
    
    private func adjustDay(_ delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

struct ScheduleCard: View {
    let schedule: Schedule
    let onDelete: (Schedule) -> Void
    let onUpdate: () -> Void
    @State private var showingEditModal = false
    @State private var showingDeleteOptions = false
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        HStack(spacing: 15) {
            // Schedule type icon
            ZStack {
                Circle()
                    .fill(schedule.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(schedule.type.icon)
                    .font(.title2)
                    .foregroundColor(schedule.type.color)
            }
            
            // Schedule details
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        // Show original title with strikethrough only if title was actually changed
                        if schedule.hasBeenModified, 
                           let originalTitle = schedule.originalTitle,
                           originalTitle != schedule.title {
                            Text(originalTitle)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .strikethrough()
                        }
                        
                        // Show current title
                        Text(schedule.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(schedule.formattedTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Show original description with strikethrough only if description was actually changed
                if schedule.hasBeenModified, 
                   let originalDescription = schedule.originalDescription,
                   originalDescription != (schedule.description ?? "") {
                    Text(originalDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .strikethrough()
                        .lineLimit(2)
                }
                
                // Show current description
                if let description = schedule.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Show actual amount if available
                if let actualAmount = schedule.actualAmount, !actualAmount.isEmpty {
                    Text("Actual: \(actualAmount) \(schedule.type == .milk ? "ml" : "grams")")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Show completion info for completed items
                if schedule.status == .completed, let completedAt = schedule.completedAt {
                    Text("Completed at \(completedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                HStack {
                    // Only show status badge if not scheduled (remove redundant scheduled tag)
                    if schedule.status != .scheduled {
                        StatusBadge(status: schedule.status)
                    }
                    
                    // No template system anymore — remove recurring label
                    
                    Spacer()
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            // Left border color based on status
            HStack {
                Rectangle()
                    .fill(schedule.status.color)
                    .frame(width: 4)
                    .cornerRadius(2, corners: [.topLeft, .bottomLeft])
                Spacer()
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showingDeleteOptions = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onTapGesture {
            showingEditModal = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showingDeleteOptions = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditModal) {
            ScheduleEditModal(schedule: schedule, onUpdate: onUpdate)
        }
        .alert("Delete Schedule", isPresented: $showingDeleteOptions) {
            Button("Delete for Today Only", role: .destructive) {
                onDelete(schedule)
            }
            Button("Delete for All Days", role: .destructive) {
                deleteTemplateForAllDays(schedule)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to delete '\(schedule.title)' for today only, or remove it from all scheduled days?")
        }
    }
    
    private func deleteTemplateForAllDays(_ schedule: Schedule) {
        Task {
            do {
                // Find the template that generated this schedule
                if let templateId = schedule.templateId {
                    try await APIClient.shared.deleteScheduleTemplate(templateId: templateId)
                    print("🗑️ Deleted template \(templateId) for all days")
                    
                    // Clear cache and reload
                    await MainActor.run {
                        onUpdate()
                    }
                } else {
                    // If no template ID, just delete the schedule
                    onDelete(schedule)
                }
            } catch {
                print("❌ Failed to delete template: \(error)")
                // Fallback to deleting just the schedule
                onDelete(schedule)
            }
        }
    }
}

struct StatusBadge: View {
    let status: ScheduleStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .cornerRadius(8)
    }
}

struct EmptyScheduleView: View {
    let date: Date
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No schedules for \(date.formatted(date: .abbreviated, time: .omitted))")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Set up daily routines or add one-time schedules")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
}

struct ChildSelectionView: View {
    @Binding var selectedChild: Child?
    @State private var children: [Child] = []
    @State private var showingAddChild = false
    @State private var isLoadingChildren = false
    
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "person.2.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Select a Child")
                .font(.title2)
                .fontWeight(.semibold)
            
            if isLoadingChildren {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    
                    Text("Loading children...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if children.isEmpty {
                VStack(spacing: 20) {
                    Text("No children added yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { 
                        print("[Schedule] Tapped Add Child")
                        showingAddChild = true 
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Child")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Text("Choose a child to view their schedule:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(children) { child in
                        Button(action: { selectedChild = child }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(child.fullName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(child.ageDescription)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add another child button - only show for parents
                    if authManager.currentCaregiver == nil {
                        Button(action: { 
                            print("[Schedule] Tapped Add Another Child")
                            showingAddChild = true 
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Another Child")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingAddChild, onDismiss: {
            showingAddChild = false
            loadChildren()
        }) {
            AddChildView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            print("[Schedule] ChildSelectionView onAppear")
            loadChildren()
        }
        .onDisappear {
            // Ensure the sheet state never blocks tab interactions when leaving
            showingAddChild = false
        }
    }
    
    private func loadChildren() {
        isLoadingChildren = true
        print("[Schedule] loadChildren - starting backend load")
        
        // Always load children from backend when this view appears
        Task {
            await dataManager.loadChildrenFromBackend()
            
            await MainActor.run {
                // Update local children array with backend data
                children = authManager.getAccessibleChildren(dataManager: dataManager)
                isLoadingChildren = false
                print("[Schedule] loadChildren - count=\(children.count) (from backend)")
            }
        }
    }
}

struct ScheduleEditModal: View {
    let schedule: Schedule
    let onUpdate: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var status: ScheduleStatus
    @State private var title: String
    @State private var description: String
    @State private var actualAmount = ""
    @State private var notes = ""
    @State private var completedAt: Date?
    @State private var isLoading = false
    
    init(schedule: Schedule, onUpdate: @escaping () -> Void) {
        self.schedule = schedule
        self.onUpdate = onUpdate
        self._status = State(initialValue: schedule.status)
        self._title = State(initialValue: schedule.title)
        self._description = State(initialValue: schedule.description ?? "")
        self._notes = State(initialValue: schedule.notes ?? "")
        self._completedAt = State(initialValue: schedule.completedAt)
        self._actualAmount = State(initialValue: schedule.actualAmount ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Header with schedule info
                    VStack(spacing: 15) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(schedule.type.color.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                
                                Text(schedule.type.icon)
                                    .font(.title)
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(schedule.title)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Scheduled: \(schedule.formattedTime)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let description = schedule.description {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Title and Description Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Schedule Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 15) {
                            TextField("Title", text: $title)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            TextField("Description (optional)", text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3...6)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Status Selection
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Status")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach([ScheduleStatus.completed, .missed, .cancelled, .scheduled], id: \.self) { statusOption in
                                Button(action: { 
                                    status = statusOption
                                    if statusOption == .completed && completedAt == nil {
                                        completedAt = Date()
                                    } else if statusOption != .completed {
                                        completedAt = nil
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Text(statusOption.icon)
                                            .font(.title3)
                                        Text(statusOption.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(status == statusOption ? statusOption.color : Color(.systemGray6))
                                    .foregroundColor(status == statusOption ? .white : .primary)
                                    .cornerRadius(25)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Amount tracking for feeding/milk
                    if schedule.type == .feeding || schedule.type == .milk {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Amount Given")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                TextField("Enter amount", text: $actualAmount)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                
                                Text(schedule.type == .milk ? "ml" : "grams")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 5)
                            }
                            
                            if !actualAmount.isEmpty {
                                Text("Scheduled vs Actual: \(schedule.description ?? "Not specified") → \(actualAmount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 5)
                            }
                        }
                    }
                    
                    // Notes Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Additional Notes")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Any additional observations or notes...", text: $notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Update Button
                    VStack(spacing: 15) {
                        Button(action: updateSchedule) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                }
                                Text("Update Schedule")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Update Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateSchedule() {
        isLoading = true
        
        // Determine if this is the first modification
        let isFirstModification = !schedule.hasBeenModified
        
        // Store original values if this is the first modification
        let originalTitle = isFirstModification ? schedule.title : schedule.originalTitle
        let originalDescription = isFirstModification ? schedule.description : schedule.originalDescription
        
        // Create updated schedule with change tracking
        let updatedSchedule = Schedule(
            id: schedule.id,
            childId: schedule.childId,
            type: schedule.type,
            title: title, // Use the new title
            description: description.isEmpty ? nil : description, // Use the new description
            scheduledTime: schedule.scheduledTime,
            status: status,
            notes: notes.isEmpty ? nil : notes,
            createdBy: schedule.createdBy,
            completedAt: completedAt,
            createdAt: schedule.createdAt,
            updatedAt: Date(),
            originalTitle: originalTitle,
            originalDescription: originalDescription,
            actualAmount: actualAmount.isEmpty ? nil : actualAmount,
            hasBeenModified: true
        )
        
        dataManager.updateSchedule(updatedSchedule)
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            onUpdate() // Notify parent to refresh schedules
            dismiss()
        }
    }
}

struct InlineAddScheduleView: View {
    let child: Child
    let date: Date
    let onScheduleAdded: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var type: ScheduleType = .feeding
    @State private var title = ""
    @State private var description = ""
    @State private var scheduledTime = Date()
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Adhoc Event")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(child.fullName) • \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Schedule Type Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(ScheduleType.allCases, id: \.self) { scheduleType in
                                Button(action: {
                                    type = scheduleType
                                }) {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(type == scheduleType ? scheduleType.color : Color(.systemGray5))
                                                .frame(width: 50, height: 50)
                                            
                                            Text(scheduleType.icon)
                                                .font(.title2)
                                                .foregroundColor(type == scheduleType ? .white : .gray)
                                        }
                                        
                                        Text(scheduleType.displayName)
                                            .font(.caption)
                                            .foregroundColor(type == scheduleType ? .primary : .secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Description Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter description (optional)", text: $description)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Time Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        DatePicker("", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Notes Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Add notes (optional)", text: $notes)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Create Button
                    Button(action: createSchedule) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            Text("Create Schedule")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(title.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(title.isEmpty || isLoading)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Add Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createSchedule() {
        guard !title.isEmpty else { return }
        
        isLoading = true
        
        // Combine the selected date with the selected time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        let finalScheduledTime = calendar.date(from: combinedComponents) ?? scheduledTime
        
        let newSchedule = Schedule(
            childId: child.id,
            type: type,
            title: title,
            description: description.isEmpty ? nil : description,
            scheduledTime: finalScheduledTime,
            status: .scheduled,
            notes: notes.isEmpty ? nil : notes,
            createdBy: authManager.currentUser?.id ?? "unknown"
        )
        
        dataManager.addSchedule(newSchedule)
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            onScheduleAdded()
        }
    }
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ScheduleView()
        .environmentObject(DataManager())
        .environmentObject(AuthenticationManager())
} 