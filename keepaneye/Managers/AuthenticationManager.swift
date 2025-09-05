import Foundation
import LocalAuthentication
import Combine

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var biometricType: LABiometryType = .none
    
    private let keychain = KeychainWrapper.standard
    private let biometricContext = LAContext()
    
    init() {
        checkBiometricType()
        checkExistingSession()
    }
    
    // MARK: - Biometric Authentication
    private func checkBiometricType() {
        var error: NSError?
        if biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = biometricContext.biometryType
        } else {
            biometricType = .none
            print("❌ Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func authenticateWithBiometrics() async -> Bool {
        return await withCheckedContinuation { continuation in
            biometricContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to access KeepAnEye") { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        continuation.resume(returning: true)
                    } else {
                        print("❌ Biometric authentication failed: \(error?.localizedDescription ?? "Unknown error")")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Session Management
    private func checkExistingSession() {
        if let userData = keychain.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) async -> Result<User, AuthError> {
        // In a real app, this would make an API call to your backend
        // For now, we'll simulate authentication
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Mock user data
            let user = User(
                id: UUID().uuidString,
                email: email,
                firstName: "John",
                lastName: "Doe",
                role: .parent,
                profileImageURL: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // Save to keychain
            if let userData = try? JSONEncoder().encode(user) {
                keychain.set(userData, forKey: "currentUser")
            }
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
            
            return .success(user)
        } catch {
            return .failure(.networkError)
        }
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String, role: UserRole) async -> Result<User, AuthError> {
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Mock user creation
            let user = User(
                id: UUID().uuidString,
                email: email,
                firstName: firstName,
                lastName: lastName,
                role: role,
                profileImageURL: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // Save to keychain
            if let userData = try? JSONEncoder().encode(user) {
                keychain.set(userData, forKey: "currentUser")
            }
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
            
            return .success(user)
        } catch {
            return .failure(.networkError)
        }
    }
    
    func signOut() {
        keychain.removeObject(forKey: "currentUser")
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - Security
    func changePassword(currentPassword: String, newPassword: String) async -> Result<Void, AuthError> {
        // In a real app, this would validate current password and update on server
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return .success(())
        } catch {
            return .failure(.networkError)
        }
    }
    
    func enableBiometricAuth() -> Bool {
        // This would typically require user to authenticate first
        return biometricType != .none
    }
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case networkError
    case biometricNotAvailable
    case biometricFailed
    case userNotFound
    case weakPassword
    case emailAlreadyInUse
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error. Please try again"
        case .biometricNotAvailable:
            return "Biometric authentication not available"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .userNotFound:
            return "User not found"
        case .weakPassword:
            return "Password is too weak"
        case .emailAlreadyInUse:
            return "Email is already in use"
        }
    }
}

// MARK: - Keychain Wrapper
class KeychainWrapper {
    static let standard = KeychainWrapper()
    
    private init() {}
    
    func set(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func data(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return result as? Data
    }
    
    func removeObject(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
} 