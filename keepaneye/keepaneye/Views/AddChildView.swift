import SwiftUI

struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var selectedGender: Gender = .preferNotToSay
    @State private var isLoading = false
    
    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Child")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Create a profile for your child")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Basic Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Child Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date of Birth")
                                .font(.headline)
                                .foregroundColor(.primary)
                            DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }
                    
                    // Gender Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gender")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(Gender.allCases, id: \.self) { gender in
                                Button(action: { selectedGender = gender }) {
                                    HStack {
                                        Text(gender.emoji)
                                        Text(gender.displayName)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(selectedGender == gender ? .white : .blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(selectedGender == gender ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Submit Button
                    Button(action: createChild) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .font(.title3)
                            }
                            Text("Add Child")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isLoading)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createChild() {
        isLoading = true
        
        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }
        
        let child = Child(
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            gender: selectedGender,
            parentId: currentUser.id
        )
        
        dataManager.addChild(child)
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    AddChildView()
        .environmentObject(DataManager())
        .environmentObject(AuthenticationManager())
} 