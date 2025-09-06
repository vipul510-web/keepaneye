import Foundation
import LocalAuthentication
import Combine
import Security

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
        print("🔍 Checking for existing session...")
        
        // Check for saved auth token
        if let tokenData = keychain.data(forKey: "authToken"),
           let token = String(data: tokenData, encoding: .utf8) {
            print("✅ Found saved auth token: \(token.prefix(20))...")
            
            // Restore token to APIClient
            APIClient.shared.setAuthToken(token)
            
            // Check for saved user data
            if let userData = keychain.data(forKey: "currentUser"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
                isAuthenticated = true
                print("✅ Restored existing session for user: \(user.email)")
            } else {
                print("⚠️ No user data found, validating token...")
                // If we have a token but no user data, try to fetch user info
                Task {
                    await validateTokenAndFetchUser(token)
                }
            }
        } else {
            print("❌ No saved auth token found")
        }
    }
    
    private func validateTokenAndFetchUser(_ token: String) async {
        do {
            let user: User = try await APIClient.shared.makeRequest("/auth/me")
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                // Save user data to keychain
                if let userData = try? JSONEncoder().encode(user) {
                    self.keychain.set(userData, forKey: "currentUser")
                }
                print("✅ Validated token and restored user: \(user.email)")
            }
        } catch {
            print("❌ Token validation failed: \(error)")
            // Token is invalid, clear everything
            await MainActor.run {
                self.signOut()
            }
        }
    }
    
    func signIn(email: String, password: String) async -> Result<User, AuthError> {
        do {
            let loginData = [
                "email": email,
                "password": password
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: loginData)
            let response: LoginResponse = try await APIClient.shared.makeRequest("/auth/login", method: "POST", body: jsonData)
            
            // Save auth token to keychain
            if let tokenData = response.token.data(using: .utf8) {
                keychain.set(tokenData, forKey: "authToken")
                print("💾 Saved auth token to keychain")
            } else {
                print("❌ Failed to save auth token to keychain")
            }
            
            // Save user data to keychain
            if let userData = try? JSONEncoder().encode(response.user) {
                keychain.set(userData, forKey: "currentUser")
                print("💾 Saved user data to keychain")
            } else {
                print("❌ Failed to save user data to keychain")
            }
            
            await MainActor.run {
                self.currentUser = response.user
                self.isAuthenticated = true
            }
            
            print("✅ User signed in successfully: \(response.user.email)")
            return .success(response.user)
            
        } catch {
            print("❌ Sign in failed: \(error)")
            return .failure(.networkError)
        }
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String, role: UserRole) async -> Result<User, AuthError> {
        do {
            let signupData = [
                "email": email,
                "password": password,
                "firstName": firstName,
                "lastName": lastName,
                "role": role.rawValue
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: signupData)
            let response: LoginResponse = try await APIClient.shared.makeRequest("/auth/register", method: "POST", body: jsonData)
            
            // Save auth token to keychain
            if let tokenData = response.token.data(using: .utf8) {
                keychain.set(tokenData, forKey: "authToken")
            }
            
            // Save user data to keychain
            if let userData = try? JSONEncoder().encode(response.user) {
                keychain.set(userData, forKey: "currentUser")
            }
            
            await MainActor.run {
                self.currentUser = response.user
                self.isAuthenticated = true
            }
            
            print("✅ User signed up successfully: \(response.user.email)")
            return .success(response.user)
            
        } catch {
            print("❌ Sign up failed: \(error)")
            return .failure(.networkError)
        }
    }
    
    func signOut() {
        // Clear auth token from APIClient
        APIClient.shared.clearAuthToken()
        
        // Clear keychain data
        keychain.removeObject(forKey: "currentUser")
        keychain.removeObject(forKey: "authToken")
        
        // Clear local state
        currentUser = nil
        isAuthenticated = false
        
        print("✅ User signed out successfully")
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

// MARK: - Auth Response Models
struct LoginResponse: Codable {
    let message: String
    let user: User
    let token: String
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