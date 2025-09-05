import SwiftUI

struct ScheduleDetailView: View {
    let schedule: Schedule
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var showingStatusUpdate = false
    @State private var selectedStatus: ScheduleStatus = .scheduled
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Schedule type icon
                    Text(schedule.type.icon)
                        .font(.system(size: 80))
                        .foregroundColor(schedule.type.color)
                    
                    // Schedule details
                    VStack(spacing: 20) {
                        Text(schedule.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        if let description = schedule.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Time and date
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                Text("Time:")
                                    .fontWeight(.medium)
                                Text(schedule.formattedTime)
                            }
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                Text("Date:")
                                    .fontWeight(.medium)
                                Text(schedule.formattedDate)
                            }
                        }
                        
                        // Status
                        VStack(spacing: 10) {
                            Text("Status:")
                                .fontWeight(.medium)
                            
                            Button(action: { 
                                selectedStatus = schedule.status
                                showingStatusUpdate = true 
                            }) {
                                HStack {
                                    Text(schedule.status.icon)
                                    Text(schedule.status.displayName)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(schedule.status.color)
                                .cornerRadius(20)
                            }
                        }
                        
                        // Notes
                        if let notes = schedule.notes {
                            VStack(spacing: 8) {
                                Text("Notes:")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                        
                    }
                    .padding()
                }
            }
            .navigationTitle("Schedule Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingStatusUpdate) {
                StatusUpdateView(schedule: schedule, selectedStatus: $selectedStatus)
            }
        }
    }
}

struct StatusUpdateView: View {
    let schedule: Schedule
    @Binding var selectedStatus: ScheduleStatus
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Update Status")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(spacing: 15) {
                    ForEach(ScheduleStatus.allCases, id: \.self) { status in
                        Button(action: { selectedStatus = status }) {
                            HStack {
                                Text(status.icon)
                                Text(status.displayName)
                                    .fontWeight(.medium)
                                Spacer()
                                if selectedStatus == status {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .foregroundColor(selectedStatus == status ? .blue : .primary)
                            .padding()
                            .background(selectedStatus == status ? Color.blue.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Button(action: updateStatus) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Update Status")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Update Status")
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
    
    private func updateStatus() {
        isLoading = true
        
        var updatedSchedule = schedule
        updatedSchedule = Schedule(
            id: schedule.id,
            childId: schedule.childId,
            type: schedule.type,
            title: schedule.title,
            description: schedule.description,
            scheduledTime: schedule.scheduledTime,
            status: selectedStatus,
            notes: schedule.notes,
            createdBy: schedule.createdBy,
            completedAt: selectedStatus == .completed ? Date() : schedule.completedAt,
            createdAt: schedule.createdAt,
            updatedAt: Date()
        )
        
        dataManager.updateSchedule(updatedSchedule)
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    ScheduleDetailView(schedule: Schedule(
        childId: "child1",
        type: .medicine,
        title: "Morning Medicine",
        description: "Give 5ml of medicine",
        scheduledTime: Date(),
        createdBy: "user1"
    ))
    .environmentObject(DataManager())
} 