import SwiftUI

struct DayPlannerView: View {
    let child: Child
    let date: Date
    let onSave: () -> Void  // Add callback for when save is successful
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var timeSlots: [TimeSlot] = []
    @State private var showingSaveOptions = false
    @State private var isLoading = false
    @State private var editingSlot: TimeSlot? = nil
    @State private var showingDeleteConfirmation = false
    @State private var slotToDelete: TimeSlot? = nil
    
    private let timeBands = [
        TimeBand(name: "Early Morning", startHour: 6, endHour: 9, icon: "sunrise"),
        TimeBand(name: "Morning", startHour: 9, endHour: 12, icon: "sun.max"),
        TimeBand(name: "Afternoon", startHour: 12, endHour: 15, icon: "sun.max.fill"),
        TimeBand(name: "Late Afternoon", startHour: 15, endHour: 18, icon: "sunset"),
        TimeBand(name: "Evening", startHour: 18, endHour: 21, icon: "moon"),
        TimeBand(name: "Night", startHour: 21, endHour: 6, icon: "moon.fill")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Plan \(child.firstName)'s Day")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("View and edit all scheduled activities")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Time Slots
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Scheduled Activities")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(timeBands) { band in
                            TimeSlotView(
                                band: band,
                                slots: timeSlots.filter { $0.bandId == band.id },
                                onAddSlot: { addSlot(to: band) },
                                onDeleteSlot: { deleteSlot($0) },
                                onEditSlot: { editSlot($0) }
                            )
                        }
                    }
                    
                    // Save Button
                    Button(action: { showingSaveOptions = true }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                            }
                            Text("Save All Activities")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(timeSlots.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(timeSlots.isEmpty || isLoading)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Activity Planner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        loadExistingSlots()
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showingSaveOptions) {
                SaveOptionsView(
                    timeSlots: timeSlots,
                    child: child,
                    onSave: { 
                        onSave()  // Call the callback to refresh schedule view
                        dismiss() 
                    }
                )
            }
            .sheet(item: $editingSlot) { slot in
                EditTimeSlotView(slot: slot) { updated in
                    if let index = timeSlots.firstIndex(where: { $0.id == updated.id }) {
                        timeSlots[index] = updated
                    } else {
                        timeSlots.append(updated)
                    }
                    timeSlots.sort { $0.time < $1.time }
                }
            }
            .alert("Delete Activity", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    confirmDelete()
                }
                Button("Cancel", role: .cancel) {
                    slotToDelete = nil
                    showingDeleteConfirmation = false
                }
            } message: {
                if let slot = slotToDelete {
                    Text("Are you sure you want to delete '\(slot.title)'? This will remove it from all scheduled days.")
                }
            }
            .onAppear {
                // Load existing slots and templates from backend
                loadExistingSlots()
            }
        }
    }
    
    private func loadExistingSlots() {
        // Build the current plan by scanning upcoming week per weekday (fresh from backend)
        Task {
            await MainActor.run { isLoading = true }
            
            let calendar = Calendar.current
            let today = Date()
            
            // Helper: next date for a given weekday (1=Sun..7=Sat)
            func nextDate(for weekday: Int) -> Date {
                var comps = calendar.dateComponents([.year, .month, .day, .weekday], from: today)
                let currentWeekday = comps.weekday ?? 1
                let diff = (weekday - currentWeekday + 7) % 7
                return calendar.date(byAdding: .day, value: diff, to: today) ?? today
            }
            
            do {
                // Accumulator keyed by title+type+time to merge weekdays
                struct SlotKey: Hashable { let title: String; let type: ScheduleType; let hour: Int; let minute: Int }
                var map: [SlotKey: TimeSlot] = [:]
                
                for weekday in 1...7 {
                    let dateForWeekday = nextDate(for: weekday)
                    // Fetch fresh to avoid cache after changes
                    let schedules = try await APIClient.shared.getSchedulesFresh(childId: child.id, date: dateForWeekday)
                    for sch in schedules {
                        let hour = calendar.component(.hour, from: sch.scheduledTime)
                        let minute = calendar.component(.minute, from: sch.scheduledTime)
                        let band = timeBands.first { $0.startHour <= hour && hour < $0.endHour } ?? timeBands[0]
                        let key = SlotKey(title: sch.title, type: sch.type, hour: hour, minute: minute)
                        if var existing = map[key] {
                            existing.selectedWeekdays.insert(weekday)
                            map[key] = existing
                        } else {
                            // Create a new slot seeded with this weekday
                            var slot = TimeSlot(
                                id: UUID().uuidString,
                                title: sch.title,
                                type: sch.type,
                                time: calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? sch.scheduledTime,
                                bandId: band.id,
                                description: sch.description,
                                selectedWeekdays: [weekday]
                            )
                            // Normalize time to today's date for stable sorting/display
                            slot.time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? slot.time
                            map[key] = slot
                        }
                    }
                }
                let merged = map.values.sorted { $0.time < $1.time }
                await MainActor.run {
                    self.timeSlots = merged
                    self.isLoading = false
                    print("✅ Loaded \(merged.count) slots from weekly schedules for \(child.firstName)")
                }
            } catch {
                print("❌ Failed to load schedules for plan: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    private func addSlot(to band: TimeBand, title: String? = nil, type: ScheduleType? = nil, hour: Int? = nil, minute: Int? = nil) {
        let chosenType = type ?? .feeding
        let newSlot = TimeSlot(
            id: UUID().uuidString,
            title: title ?? chosenType.displayName,
            type: chosenType,
            time: createTime(hour: hour ?? band.startHour, minute: minute ?? 0),
            bandId: band.id,
            description: nil,
            selectedWeekdays: [Calendar.current.component(.weekday, from: date)]
        )
        // Do not add yet; only add when user taps Save in editor
        editingSlot = newSlot
    }
    
    private func deleteSlot(_ slot: TimeSlot) {
        slotToDelete = slot
        showingDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        guard let slot = slotToDelete else { return }
        // Remove from local array
        timeSlots.removeAll { $0.id == slot.id }
        slotToDelete = nil
        showingDeleteConfirmation = false
        // Persist the updated plan by replacing schedules
        persistCurrentPlanReplace()
    }

    private func persistCurrentPlanReplace() {
        Task {
            do {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm:ss"
                let plan: [ReplacePlanItem] = timeSlots.compactMap { slot in
                    let weekdays = Array(slot.selectedWeekdays).sorted()
                    guard !weekdays.isEmpty else { return nil }
                    return ReplacePlanItem(
                        title: slot.title,
                        type: slot.type.rawValue,
                        description: slot.description,
                        timeOfDay: timeFormatter.string(from: slot.time),
                        weekdays: weekdays,
                        notes: nil
                    )
                }
                let resp = try await APIClient.shared.replaceSchedules(childId: child.id, plan: plan, startDate: nil, weeks: 8)
                print("✅ Replaced schedules: deleted=\(resp.deleted), created=\(resp.created)")
                // Reload plan from backend to reflect actual stored state
                loadExistingSlots()
            } catch {
                print("❌ Failed to replace schedules: \(error)")
            }
        }
    }
    
    private func editSlot(_ slot: TimeSlot) {
        editingSlot = slot
    }
    
    private func createTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
    
    private func loadTemplatesFromBackend() {
        // This function is now handled in loadExistingSlots
        // Templates are loaded there to get weekday information for existing slots
    }
}

struct TimeBand: Identifiable {
    let id = UUID()
    let name: String
    let startHour: Int
    let endHour: Int
    let icon: String
}

struct TimeSlot: Identifiable, Equatable {
    var id: String
    var title: String
    var type: ScheduleType
    var time: Date
    var bandId: UUID
    var description: String?
    var selectedWeekdays: Set<Int> = [] // Each slot can have its own weekday configuration
}

struct EditTimeSlotView: View {
    @Environment(\.dismiss) private var dismiss
    @State var slot: TimeSlot
    var onSave: (TimeSlot) -> Void
    @State private var userEditedTitle = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(ScheduleType.allCases, id: \.self) { t in
                                Button(action: {
                                    let previousType = slot.type
                                    slot.type = t
                                    if !userEditedTitle || slot.title.isEmpty || slot.title == previousType.displayName {
                                        slot.title = t.displayName
                                    }
                                }) {
                                    HStack {
                                        Text(t.icon)
                                        Text(t.displayName)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(slot.type == t ? Color.blue : Color(.systemGray6))
                                    .foregroundColor(slot.type == t ? .white : .primary)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Title")
                            .font(.headline)
                        TextField("Enter title (e.g., Lunch)", text: $slot.title)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .onChange(of: slot.title) { _ in
                                userEditedTitle = true
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)
                        TextField("Optional details", text: Binding(get: { slot.description ?? "" }, set: { slot.description = $0.isEmpty ? nil : $0 }))
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time")
                            .font(.headline)
                        DatePicker("", selection: $slot.time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Individual weekday selector for this slot
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Apply to Days")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        WeekdaySelector(selectedDays: $slot.selectedWeekdays)
                        
                        Text("Select which days this activity should occur")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // If title is empty, default to the selected type's name
                        var toSave = slot
                        if toSave.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            toSave.title = toSave.type.displayName
                        }
                        onSave(toSave)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QuickPresetButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TimeSlotView: View {
    let band: TimeBand
    let slots: [TimeSlot]
    let onAddSlot: () -> Void
    let onDeleteSlot: (TimeSlot) -> Void
    let onEditSlot: (TimeSlot) -> Void
    
    private func weekdayName(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "?"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: band.icon)
                    .foregroundColor(.blue)
                Text(band.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: onAddSlot) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            if slots.isEmpty {
                Text("No activities planned")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
            } else {
                ForEach(slots) { slot in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Button(action: { onEditSlot(slot) }) {
                                HStack {
                                    Text(slot.type.icon)
                                    VStack(alignment: .leading) {
                                        Text(slot.title)
                                            .font(.subheadline)
                                        if let desc = slot.description, !desc.isEmpty {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(slot.time.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: { onDeleteSlot(slot) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        
                        // Show which days this slot applies to
                        if !slot.selectedWeekdays.isEmpty {
                            HStack(spacing: 4) {
                                Text("Days:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                ForEach(Array(slot.selectedWeekdays).sorted(), id: \.self) { weekday in
                                    Text(weekdayName(for: weekday))
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

struct WeekdaySelector: View {
    @Binding var selectedDays: Set<Int>
    
    private let weekdays = [
        (1, "Sun"),
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat")
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekdays, id: \.0) { day in
                Button(action: {
                    if selectedDays.contains(day.0) {
                        selectedDays.remove(day.0)
                    } else {
                        selectedDays.insert(day.0)
                    }
                }) {
                    Text(day.1)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 32, height: 32)
                        .background(selectedDays.contains(day.0) ? Color.blue : Color(.systemGray6))
                        .foregroundColor(selectedDays.contains(day.0) ? .white : .primary)
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct SaveOptionsView: View {
    let timeSlots: [TimeSlot]
    let child: Child
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var isLoading = false
    @State private var saveAsTemplate = false
    @State private var templateName = ""
    
    private var totalWeekdays: Int {
        let allWeekdays = Set(timeSlots.flatMap { $0.selectedWeekdays })
        return allWeekdays.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Save Options")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• \(timeSlots.count) activities configured")
                            Text("• Activities span \(totalWeekdays) different days")
                            Text("• Child: \(child.firstName)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    // Template UI removed (no templates flow)
                    
                    // Save Button
                    Button(action: savePlan) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                            }
                            Text("Save All Activities")
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
                .padding()
            }
            .navigationTitle("Save Activities")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func savePlan() {
        isLoading = true
        
        Task {
            do {
                // Build replace plan from current slots (no templates)
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm:ss"
                let plan: [ReplacePlanItem] = timeSlots.compactMap { slot in
                    let weekdays = Array(slot.selectedWeekdays).sorted()
                    guard !weekdays.isEmpty else { return nil }
                    return ReplacePlanItem(
                        title: slot.title,
                        type: slot.type.rawValue,
                        description: slot.description,
                        timeOfDay: timeFormatter.string(from: slot.time),
                        weekdays: weekdays,
                        notes: nil
                    )
                }
                let resp = try await APIClient.shared.replaceSchedules(childId: child.id, plan: plan, startDate: nil, weeks: 8)
                print("✅ Saved plan by replace: deleted=\(resp.deleted), created=\(resp.created)")
                
                await MainActor.run {
                    isLoading = false
                    onSave()
                    dismiss()
                }
            } catch {
                print("❌ Failed to save plan: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    DayPlannerView(
        child: Child(
            firstName: "Emma",
            lastName: "Smith",
            dateOfBirth: Date(),
            gender: .female,
            parentId: "parent1"
        ),
        date: Date(),
        onSave: {
            // Preview callback - do nothing
        }
    )
    .environmentObject(DataManager())
} 