import SwiftUI

// MARK: - Caregiver Management View (temporary placement)
struct CaregiverManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var caregivers: [Caregiver] = []
    @State private var showingAddCaregiver = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if caregivers.isEmpty {
                    EmptyCaregiversView(showingAddCaregiver: $showingAddCaregiver)
                } else {
                    List {
                        ForEach(caregivers) { caregiver in
                            CaregiverCard(caregiver: caregiver, children: dataManager.children)
                        }
                        .onDelete(perform: deleteCaregiver)
                    }
                }
            }
            .navigationTitle("Caregivers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCaregiver = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddCaregiver, onDismiss: {
                // Reload caregivers after adding one so the list updates immediately
                loadCaregivers()
            }) {
                AddCaregiverView()
            }
            .onAppear {
                loadCaregivers()
                print("[Profile] CaregiverManagementView onAppear - caregivers=\(caregivers.count)")
            }
            // Keep the list in sync with DataManager updates
            .onReceive(dataManager.$caregivers) { _ in
                loadCaregivers()
            }
        }
    }
    
    private func loadCaregivers() {
        guard let currentUser = authManager.currentUser else { return }
        caregivers = dataManager.getCaregivers(for: currentUser.id)
    }
    
    private func deleteCaregiver(offsets: IndexSet) {
        for index in offsets {
            let caregiver = caregivers[index]
            dataManager.deleteCaregiver(caregiver)
        }
        loadCaregivers()
    }
}

struct EmptyCaregiversView: View {
    @Binding var showingAddCaregiver: Bool
    
    var body: some View {
            VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "person.2.circle")
                    .font(.system(size: 80))
                .foregroundColor(.secondary)
                
            VStack(spacing: 15) {
                Text("No Caregivers Added")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add nurses, nannies, or family members to help care for your children")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: { showingAddCaregiver = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Caregiver")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct CaregiverCard: View {
    let caregiver: Caregiver
    let children: [Child]
    @EnvironmentObject var dataManager: DataManager
    @State private var showingEditCaregiver = false
    
    var assignedChildren: [Child] {
        children.filter { caregiver.assignedChildIds.contains($0.id) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(caregiver.role.icon)
                            .font(.title2)
                        
                        Text(caregiver.fullName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: { showingEditCaregiver = true }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(caregiver.role.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(caregiver.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !assignedChildren.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assigned to:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(assignedChildren) { child in
                            HStack(spacing: 4) {
                                Text(child.gender.emoji)
                                Text(child.firstName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                }
            } else {
                Text("No children assigned")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingEditCaregiver) {
            EditCaregiverView(caregiver: caregiver)
        }
    }
}

struct AddCaregiverView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var role: CaregiverRole = .nurse
    @State private var selectedChildIds: Set<String> = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Caregiver")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Invite someone to help care for your children")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Role Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Role")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(CaregiverRole.allCases, id: \.self) { caregiverRole in
                                Button(action: {
                                    role = caregiverRole
                                }) {
                                    HStack {
                                        Text(caregiverRole.icon)
                                        Text(caregiverRole.displayName)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(role == caregiverRole ? .white : .blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(role == caregiverRole ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Personal Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personal Information")
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
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        TextField("Phone Number (Optional)", text: $phoneNumber)
                            .textFieldStyle(.plain)
                            .keyboardType(.phonePad)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Child Assignment
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assign to Children")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(dataManager.children) { child in
                            Button(action: {
                                if selectedChildIds.contains(child.id) {
                                    selectedChildIds.remove(child.id)
                                } else {
                                    selectedChildIds.insert(child.id)
                                }
                            }) {
                                HStack {
                                    Text(child.gender.emoji)
                                    Text(child.fullName)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    if selectedChildIds.contains(child.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Add Button
                    Button(action: addCaregiver) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            Text("Add Caregiver")
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
            .navigationTitle("Add Caregiver")
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
    
    private var isFormValid: Bool {
        !email.isEmpty && !firstName.isEmpty && !lastName.isEmpty && !selectedChildIds.isEmpty
    }
    
    private func addCaregiver() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLoading = true
        
        Task {
            do {
                // First, create the caregiver account in the backend
                let caregiverUser = try await authManager.createCaregiverAccount(
                    email: email,
                    password: "tempPassword123", // Caregiver will change this when they first login
                    firstName: firstName,
                    lastName: lastName
                )
                
                // Create local caregiver record
                let newCaregiver = Caregiver(
                    id: caregiverUser.id,
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                    role: role,
                    assignedChildIds: Array(selectedChildIds),
                    createdBy: currentUser.id
                )
                
                // Add caregiver locally
                dataManager.addCaregiver(newCaregiver)
                
                // Assign caregiver to each selected child in the backend
                for childId in selectedChildIds {
                    try await authManager.assignCaregiverToChild(
                        caregiverId: email, // Backend expects email
                        childId: childId
                    )
                }
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // You might want to show an error alert here
                    print("❌ Failed to add caregiver: \(error)")
                }
            }
        }
    }
}

struct EditCaregiverView: View {
    let caregiver: Caregiver
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var firstName: String
    @State private var lastName: String
    @State private var phoneNumber: String
    @State private var role: CaregiverRole
    @State private var selectedChildIds: Set<String>
    @State private var isLoading = false
    
    init(caregiver: Caregiver) {
        self.caregiver = caregiver
        _firstName = State(initialValue: caregiver.firstName)
        _lastName = State(initialValue: caregiver.lastName)
        _phoneNumber = State(initialValue: caregiver.phoneNumber ?? "")
        _role = State(initialValue: caregiver.role)
        _selectedChildIds = State(initialValue: Set(caregiver.assignedChildIds))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Edit Caregiver")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Update caregiver information and assignments")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Role Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Role")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(CaregiverRole.allCases, id: \.self) { caregiverRole in
                                Button(action: {
                                    role = caregiverRole
                                }) {
                                    HStack {
                                        Text(caregiverRole.icon)
                                        Text(caregiverRole.displayName)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(role == caregiverRole ? .white : .blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(role == caregiverRole ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Personal Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personal Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Email: \(caregiver.email)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Phone Number (Optional)", text: $phoneNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)
                    }
                    
                    // Child Assignment
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assign to Children")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(dataManager.children) { child in
                            Button(action: {
                                if selectedChildIds.contains(child.id) {
                                    selectedChildIds.remove(child.id)
                                } else {
                                    selectedChildIds.insert(child.id)
                                }
                            }) {
                                HStack {
                                    Text(child.gender.emoji)
                                    Text(child.fullName)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    if selectedChildIds.contains(child.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Update Button
                    Button(action: updateCaregiver) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                            }
                            Text("Update Caregiver")
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
            .navigationTitle("Edit Caregiver")
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
    
    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !selectedChildIds.isEmpty
    }
    
    private func updateCaregiver() {
        isLoading = true
        
        let updatedCaregiver = Caregiver(
            id: caregiver.id,
            email: caregiver.email,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            role: role,
            assignedChildIds: Array(selectedChildIds),
            createdBy: caregiver.createdBy,
            createdAt: caregiver.createdAt,
            updatedAt: Date(),
            isActive: caregiver.isActive
        )
        
        dataManager.updateCaregiver(updatedCaregiver)
        
        // Simulate a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var consentManager: ConsentManager
    @State private var showingCaregiverManagement = false
    @State private var showingConsent = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    VStack(spacing: 20) {
                        // Profile Image
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                        }
                        
                        // User Info
                        VStack(spacing: 8) {
                            if let user = authManager.currentUser {
                                Text(user.fullName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(user.role.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            } else if let caregiver = authManager.currentCaregiver {
                                Text(caregiver.fullName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(caregiver.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 6) {
                                    Text(caregiver.role.icon)
                                        .font(.caption)
                                    Text(caregiver.role.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Privacy & Consent
                        Button(action: { showingConsent = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Privacy & Consent")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text("View or change data sharing preferences")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                        }
                                            .buttonStyle(PlainButtonStyle())
                    
                    // Manage Caregivers (only for parents)
                        if let user = authManager.currentUser, user.role == .parent {
                            Button(action: { showingCaregiverManagement = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.2.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Manage Caregivers")
                                            .font(.headline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text("Add nurses, nannies, and family members")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray5), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Sign Out Button
                        Button(action: { 
                            print("[Profile] Tapped sign out")
                            authManager.signOut() 
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sign Out")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                    
                                    Text("Sign out of your account")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 50)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingCaregiverManagement) {
                CaregiverManagementView()
            }
        }
        .onAppear {
            let isParent = authManager.currentUser != nil
            print("[Profile] onAppear - isParent=\(isParent), user=\(authManager.currentUser?.email ?? "nil"), caregiver=\(authManager.currentCaregiver?.email ?? "nil")")
            
            // Load caregivers from backend when profile view appears (only for parents)
            if isParent {
                Task {
                    await dataManager.loadCaregiversFromBackend()
                }
            }
        }
        .sheet(isPresented: $showingConsent) {
            PolicyConsentView()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
} 