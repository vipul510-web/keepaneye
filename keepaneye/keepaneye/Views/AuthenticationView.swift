import SwiftUI

struct AuthenticationView: View {
    @State private var isSignUp = false
    @State private var isCaregiverLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedRole: UserRole = .parent
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // App Logo and Title
                        VStack(spacing: 20) {
                            Image(systemName: "eye.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            Text("KeepAnEye")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Secure child care coordination")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                        
                        // Authentication Form
                        VStack(spacing: 20) {
                            if isSignUp {
                                // Sign Up Fields
                                VStack(spacing: 15) {
                                    HStack(spacing: 15) {
                                        CustomTextField(
                                            text: $firstName,
                                            placeholder: "First Name",
                                            icon: "person"
                                        )
                                        
                                        CustomTextField(
                                            text: $lastName,
                                            placeholder: "Last Name",
                                            icon: "person"
                                        )
                                    }
                                    
                                    CustomTextField(
                                        text: $email,
                                        placeholder: "Email",
                                        icon: "envelope"
                                    )
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    
                                    CustomTextField(
                                        text: $password,
                                        placeholder: "Password",
                                        icon: "lock",
                                        isSecure: true
                                    )
                                    
                                    // Role Selection
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("I am a:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        HStack(spacing: 15) {
                                            ForEach(UserRole.allCases, id: \.self) { role in
                                                RoleButton(
                                                    role: role,
                                                    isSelected: selectedRole == role,
                                                    action: { selectedRole = role }
                                                )
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Sign In Fields
                                VStack(spacing: 15) {
                                    // Mode indicator
                                    if isCaregiverLogin {
                                        HStack {
                                            Image(systemName: "person.2.circle.fill")
                                            Text("Caregiver Mode")
                                        }
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                    
                                    CustomTextField(
                                        text: $email,
                                        placeholder: "Email",
                                        icon: "envelope"
                                    )
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .onChange(of: email) { newEmail in
                                        // Auto-detect caregiver emails and set mode
                                        if newEmail.contains("gina") || newEmail.contains("nurse") || newEmail.contains("caregiver") {
                                            isCaregiverLogin = true
                                            print("🔀 Auto-detected caregiver email, set caregiver mode")
                                        }
                                    }
                                    
                                    CustomTextField(
                                        text: $password,
                                        placeholder: "Password",
                                        icon: "lock",
                                        isSecure: true
                                    )

                                    // Caregiver-specific hint
                                    if isCaregiverLogin {
                                        Text("First time signing in? Enter a new password to set up your caregiver account.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            
                            // Action Button
                            Button(action: handleAuthentication) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text(isSignUp ? "Create Account" : (isCaregiverLogin ? "Sign In as Caregiver" : "Sign In"))
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isCaregiverLogin ? Color.orange : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading || !isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.6)
                            
                            // Toggle Sign In/Sign Up (hidden in caregiver mode)
                            if !isCaregiverLogin {
                                Button(action: { isSignUp.toggle() }) {
                                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                        .foregroundColor(.blue)
                                        .font(.subheadline)
                                }
                            }
                            
                                                            // Caregiver Login Option
                                if !isSignUp {
                                    Divider()
                                        .padding(.vertical, 10)
                                    
                                    Button(action: { 
                                        isCaregiverLogin.toggle()
                                        print("🔀 Toggled caregiver login: \(isCaregiverLogin)")
                                    }) {
                                        HStack {
                                            Image(systemName: "person.2.circle")
                                            Text(isCaregiverLogin ? "Sign in as Parent" : "Sign in as Caregiver")
                                        }
                                        .foregroundColor(.blue)
                                        .font(.subheadline)
                                    }
                                    
                                    // Show warning if caregiver email detected but not in caregiver mode
                                    if !isCaregiverLogin && email.contains("@") && (email.contains("gina") || email.contains("nurse") || email.contains("caregiver")) {
                                        Text("⚠️ This looks like a caregiver email. Click 'Sign in as Caregiver' above.")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .padding(.top, 5)
                                    }
                                }
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !firstName.isEmpty && !lastName.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func handleAuthentication() {
        isLoading = true
        
        Task {
            if isCaregiverLogin {
                let result = await authManager.signInAsCaregiver(email: email, password: password, dataManager: dataManager)
                
                await MainActor.run {
                    isLoading = false
                    
                    switch result {
                    case .success(_):
                        // Success - caregiver is automatically signed in
                        // Load children from backend after successful login
                        Task {
                            await dataManager.loadChildrenFromBackend()
                        }
                        break
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } else {
                let result: Result<User, AuthError>
                
                if isSignUp {
                    result = await authManager.signUp(
                        email: email,
                        password: password,
                        firstName: firstName,
                        lastName: lastName,
                        role: selectedRole
                    )
                } else {
                    result = await authManager.signIn(email: email, password: password)
                }
                
                await MainActor.run {
                    isLoading = false
                    
                    switch result {
                    case .success(_):
                        // Success - user is automatically signed in
                        // Load children and caregivers from backend after successful login
                        Task {
                            await dataManager.loadChildrenFromBackend()
                            // Only load caregivers if the user is a parent
                            if authManager.currentUser != nil {
                                await dataManager.loadCaregiversFromBackend()
                            }
                        }
                        break
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
}

// MARK: - Custom Components
struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RoleButton: View {
    let role: UserRole
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(role.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager())
} 