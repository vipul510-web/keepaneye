import SwiftUI

struct ScheduleTemplateView: View {
    let child: Child
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var showingAddTemplate = false
    @State private var templates: [ScheduleTemplate] = []
    @State private var showingDeleteAlert = false
    @State private var templateToDelete: ScheduleTemplate?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 15) {
                    HStack {
                        Text(child.gender.emoji)
                            .font(.title)
                        Text("\(child.firstName)'s Routines")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Set up recurring schedules that will appear automatically")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Templates List
                if templates.isEmpty {
                    EmptyTemplateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(templates) { template in
                                ScheduleTemplateCard(
                                    template: template,
                                    onDelete: { deleteTemplate in
                                        templateToDelete = deleteTemplate
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Routines")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTemplate = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddTemplate) {
                AddScheduleTemplateView(child: child)
            }
            .alert("Delete Routine", isPresented: $showingDeleteAlert) {
                Button("Delete for Today Only", role: .destructive) {
                    if let template = templateToDelete {
                        deleteTemplateForToday(template)
                    }
                }
                Button("Delete for All Days", role: .destructive) {
                    if let template = templateToDelete {
                        deleteTemplateForAllDays(template)
                    }
                }
                Button("Cancel", role: .cancel) {
                    templateToDelete = nil
                }
            } message: {
                if let template = templateToDelete {
                    Text("How would you like to delete '\(template.name)'?")
                }
            }
            .onAppear {
                loadTemplates()
            }
        }
    }
    
    private func loadTemplates() {
        templates = dataManager.getScheduleTemplates(for: child.id)
    }
    
    private func deleteTemplateForToday(_ template: ScheduleTemplate) {
        // Delete only today's schedule generated from this template
        let today = Date()
        let schedules = dataManager.getSchedules(for: child.id, on: today)
        let todaySchedules = schedules.filter { $0.templateId == template.id }
        
        for schedule in todaySchedules {
            dataManager.deleteSchedule(schedule)
        }
        
        // Reload templates
        loadTemplates()
    }
    
    private func deleteTemplateForAllDays(_ template: ScheduleTemplate) {
        // Delete the template itself (which removes it from all future days)
        dataManager.deleteScheduleTemplate(template)
        
        // Reload templates
        loadTemplates()
    }
}

struct ScheduleTemplateCard: View {
    let template: ScheduleTemplate
    let onDelete: (ScheduleTemplate) -> Void
    @State private var showingEdit = false
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
            HStack(spacing: 15) {
                // Template type icon
                ZStack {
                    Circle()
                        .fill(template.type.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Text(template.type.icon)
                        .font(.title2)
                        .foregroundColor(template.type.color)
                }
                
                // Template details
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(template.formattedTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(template.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                
                HStack {
                    Text(template.frequency.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(template.frequency == .daily ? Color.blue.opacity(0.2) : 
                                   template.frequency == .weekly ? Color.green.opacity(0.2) : Color.purple.opacity(0.2))
                        .foregroundColor(template.frequency == .daily ? .blue : 
                                       template.frequency == .weekly ? .green : .purple)
                        .cornerRadius(6)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
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
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(template)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditScheduleTemplateView(template: template)
        }
    }
}

struct EmptyTemplateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No routines set up yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Create recurring schedules like daily breakfast, weekly bath, or monthly checkups")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 100)
    }
}

struct AddScheduleTemplateView: View {
    let child: Child
    var onCreated: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var name = ""
    @State private var selectedType: ScheduleType = .feeding
    @State private var title = ""
    @State private var description = ""
    @State private var timeOfDay = Date()
    @State private var selectedFrequency: ScheduleFrequency = .daily
    @State private var notes = ""
    @State private var isLoading = false
    @State private var showingRoutinesList = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Routine Details Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Routine Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Routine Name (e.g., Daily Breakfast)", text: $name)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        // Type Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Type")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                ForEach(ScheduleType.allCases, id: \.self) { type in
                                    Button(action: { selectedType = type }) {
                                        HStack(spacing: 8) {
                                            Text(type.icon)
                                                .font(.title3)
                                            Text(type.displayName)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(selectedType == type ? Color.blue : Color(.systemGray6))
                                        .foregroundColor(selectedType == type ? .white : .primary)
                                        .cornerRadius(25)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    // Schedule Details Section
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
                    
                    // Time Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Time")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        DatePicker("Time of Day", selection: $timeOfDay, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Notes Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Notes (optional)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextField("Additional notes", text: $notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Buttons Section
                    VStack(spacing: 15) {
                        Button(action: createTemplate) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                                Text("Create \(selectedFrequency.displayName) Routine")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background((name.isEmpty || title.isEmpty) ? Color(.systemGray4) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || name.isEmpty || title.isEmpty)
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { showingRoutinesList = true }) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("View All Routines")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Add a Routine")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRoutinesList) {
                RoutinesListView(child: child)
            }
        }
    }
    
    private func createTemplate() {
        isLoading = true
        
        let template = ScheduleTemplate(
            childId: child.id,
            name: name,
            type: selectedType,
            title: title,
            description: description.isEmpty ? nil : description,
            timeOfDay: timeOfDay,
            frequency: selectedFrequency,
            notes: notes.isEmpty ? nil : notes,
            createdBy: "current_user" // In a real app, this would be the current user's ID
        )
        
        dataManager.addScheduleTemplate(template)
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            if let onCreated = onCreated {
                onCreated()
                dismiss()
            } else {
                showingRoutinesList = true
            }
        }
    }
}

struct EditScheduleTemplateView: View {
    let template: ScheduleTemplate
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var name: String
    @State private var selectedType: ScheduleType
    @State private var title: String
    @State private var description: String
    @State private var timeOfDay: Date
    @State private var selectedFrequency: ScheduleFrequency
    @State private var notes: String
    @State private var isLoading = false
    
    init(template: ScheduleTemplate) {
        self.template = template
        _name = State(initialValue: template.name)
        _selectedType = State(initialValue: template.type)
        _title = State(initialValue: template.title)
        _description = State(initialValue: template.description ?? "")
        _timeOfDay = State(initialValue: template.timeOfDay)
        _selectedFrequency = State(initialValue: template.frequency)
        _notes = State(initialValue: template.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Routine Details") {
                    TextField("Routine Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(ScheduleType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Picker("Frequency", selection: $selectedFrequency) {
                        ForEach(ScheduleFrequency.allCases, id: \.self) { frequency in
                            HStack {
                                Text(frequency.icon)
                                Text(frequency.displayName)
                            }
                            .tag(frequency)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Section("Schedule Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Section("Time") {
                    DatePicker("Time of Day", selection: $timeOfDay, displayedComponents: .hourAndMinute)
                }
                
                Section("Notes") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Section("Actions") {
                    Button(action: updateTemplate) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("Update Routine")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading || name.isEmpty || title.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Edit Routine")
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
    
    private func updateTemplate() {
        isLoading = true
        
        let updatedTemplate = ScheduleTemplate(
            id: template.id,
            childId: template.childId,
            name: name,
            type: selectedType,
            title: title,
            description: description.isEmpty ? nil : description,
            timeOfDay: timeOfDay,
            frequency: selectedFrequency,
            notes: notes.isEmpty ? nil : notes,
            createdBy: template.createdBy,
            isActive: template.isActive,
            createdAt: template.createdAt,
            updatedAt: Date()
        )
        
        dataManager.updateScheduleTemplate(updatedTemplate)
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    ScheduleTemplateView(child: Child(
        firstName: "Emma",
        lastName: "Smith",
        dateOfBirth: Date(),
        gender: .female,
        parentId: "parent1"
    ))
    .environmentObject(DataManager())
}

struct RoutinesListView: View {
    let child: Child
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 15) {
                    HStack {
                        Text(child.gender.emoji)
                            .font(.title)
                        Text("\(child.firstName)'s Routines")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text("All your recurring schedules")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Routines List
                let templates = dataManager.getScheduleTemplates(for: child.id)
                if templates.isEmpty {
                    EmptyTemplateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(templates) { template in
                                ScheduleTemplateCard(
                                    template: template,
                                    onDelete: { deleteTemplate in
                                        // Handle deletion if needed
                                        print("Delete routine: \(deleteTemplate.name)")
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("All Routines")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 