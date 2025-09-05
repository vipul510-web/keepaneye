import SwiftUI

struct AddScheduleView: View {
    let child: Child
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var selectedType: ScheduleType = .feeding
    @State private var title = ""
    @State private var userEditedTitle = false
    @FocusState private var isTitleFocused: Bool
    @State private var description = ""
    @State private var scheduledTime = Date()
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Schedule Type Selection
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Schedule Type")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(ScheduleType.allCases, id: \.self) { type in
                                Button(action: {
                                    let previousType = selectedType
                                    selectedType = type
                                    if !userEditedTitle || title.isEmpty || title == previousType.displayName {
                                        title = type.displayName
                                    }
                                }) {
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
                
                    // Details Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 15) {
                    TextField("Title", text: $title)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .focused($isTitleFocused)
                                .onChange(of: title) { _ in
                                    if isTitleFocused { userEditedTitle = true }
                                }
                    
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
                        
                    DatePicker("Scheduled Time", selection: $scheduledTime, displayedComponents: [.date, .hourAndMinute])
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
                
                    // Create Button
                    VStack(spacing: 15) {
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
                            .background(title.isEmpty ? Color(.systemGray4) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(isLoading || title.isEmpty)
                        .buttonStyle(PlainButtonStyle())
                }
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
            .onAppear {
                if title.isEmpty {
                    title = selectedType.displayName
                }
            }
        }
    }
    
    private func createSchedule() {
        isLoading = true
        
        let schedule = Schedule(
            childId: child.id,
            type: selectedType,
            title: title,
            description: description.isEmpty ? nil : description,
            scheduledTime: scheduledTime,
            notes: notes.isEmpty ? nil : notes,
            createdBy: "current_user" // In a real app, this would be the current user's ID
        )
        
        dataManager.addSchedule(schedule)
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    AddScheduleView(child: Child(
        firstName: "Emma",
        lastName: "Smith",
        dateOfBirth: Date(),
        gender: .female,
        parentId: "parent1"
    ))
    .environmentObject(DataManager())
} 