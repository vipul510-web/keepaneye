import Foundation
import LocalAuthentication
import Combine

// MARK: - API Client (temporary placement)
class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let baseURL = "https://keepaneye-2e2nuzus2-gaurav-agarwals-projects-ee8f97ee.vercel.app/api"
    private var authToken: String?
    private let jsonDecoder: JSONDecoder
    
    // Cache for API responses
    private var scheduleCache: [String: (schedules: [Schedule], timestamp: Date)] = [:]
    private var templateCache: [String: (templates: [ScheduleTemplate], timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Fallback to standard ISO8601 format without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
    }
    
    func setAuthToken(_ token: String) {
        print("🔐 Setting auth token: \(token.prefix(20))...")
        self.authToken = token
    }
    
    func clearAuthToken() {
        print("🔐 Clearing auth token")
        self.authToken = nil
        // Clear cache when token is cleared
        clearCache()
    }
    
    func getAuthToken() -> String? {
        return authToken
    }
    
    // MARK: - Cache Management
    private func clearCache() {
        scheduleCache.removeAll()
        templateCache.removeAll()
        print("🗑️ Cleared API cache")
    }
    
    private func getCacheKey(childId: String, date: Date? = nil) -> String {
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return "\(childId)_\(formatter.string(from: date))"
        }
        return childId
    }
    
    private func isCacheValid(for key: String, cache: [String: (timestamp: Date, any: Any)]) -> Bool {
        guard let cached = cache[key] else { return false }
        return Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval
    }
    
    func makeRequest<T: Codable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            print("❌ Invalid URL: \(baseURL)\(endpoint)")
            throw APIError.invalidURL
        }
        
        print("🌐 Making request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 Adding Authorization header: Bearer \(token.prefix(20))...")
        } else {
            print("⚠️ No auth token available")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 {
                print("❌ Unauthorized")
                throw APIError.unauthorized
            }
            
            if httpResponse.statusCode >= 400 {
                print("❌ Server error: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Response body: \(responseString)")
                }
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            // Debug: Print response data for successful requests
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 Response data: \(responseString)")
            }
            
            do {
                return try jsonDecoder.decode(T.self, from: data)
            } catch {
                print("❌ JSON Decoding error: \(error)")
                throw APIError.decodingError
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw APIError.serverError(0)
        }
    }
    
    // MARK: - Auth Endpoints
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode([
            "email": email,
            "password": password
        ])
        
        let response: AuthResponse = try await makeRequest("/auth/login", method: "POST", body: body)
        setAuthToken(response.token)
        return response
    }
    
    func register(email: String, password: String, firstName: String, lastName: String, role: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode([
            "email": email,
            "password": password,
            "firstName": firstName,
            "lastName": lastName,
            "role": role
        ])
        
        let response: AuthResponse = try await makeRequest("/auth/register", method: "POST", body: body)
        setAuthToken(response.token)
        return response
    }
    
    func setupCaregiverAccount(email: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode([
            "email": email,
            "password": password
        ])
        
        let response: AuthResponse = try await makeRequest("/auth/caregiver-setup", method: "POST", body: body)
        setAuthToken(response.token)
        return response
    }
    
    // MARK: - Schedule Template Endpoints
    func getScheduleTemplates(childId: String) async throws -> [ScheduleTemplate] {
        let cacheKey = getCacheKey(childId: childId)
        
        // Check cache first
        if let cached = templateCache[cacheKey], 
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            print("📦 Using cached templates for child: \(childId)")
            return cached.templates
        }
        
        let response: TemplatesResponse = try await makeRequest("/schedule-templates?childId=\(childId)")
        
        // Cache the result
        templateCache[cacheKey] = (templates: response.templates, timestamp: Date())
        print("💾 Cached templates for child: \(childId)")
        
        return response.templates
    }
    
    func bulkUpsertTemplates(childId: String, items: [TemplateItem]) async throws -> BulkUpsertResponse {
        let request = BulkUpsertRequest(childId: childId, items: items)
        let body = try JSONEncoder().encode(request)
        
        let response: BulkUpsertResponse = try await makeRequest("/schedule-templates/bulk-upsert", method: "POST", body: body)
        
        // Invalidate template cache for this child
        let cacheKey = getCacheKey(childId: childId)
        templateCache.removeValue(forKey: cacheKey)
        print("🗑️ Invalidated template cache for child: \(childId)")
        
        // Also clear schedule cache to ensure fresh data
        scheduleCache.removeAll()
        print("🗑️ Cleared ALL schedule cache after template updates")
        
        return response
    }
    
    func deleteScheduleTemplate(templateId: String) async throws {
        let response: DeleteTemplateResponse = try await makeRequest("/schedule-templates/\(templateId)", method: "DELETE")
        
        // Invalidate template cache for the specific child
        let cacheKey = getCacheKey(childId: response.childId)
        templateCache.removeValue(forKey: cacheKey)
        
        // Also invalidate all schedule caches for this child
        // We need to clear all date-specific caches for this child
        let keysToRemove = scheduleCache.keys.filter { $0.hasPrefix(response.childId) }
        for key in keysToRemove {
            scheduleCache.removeValue(forKey: key)
        }
        
        // Clear all caches to ensure fresh data
        templateCache.removeAll()
        scheduleCache.removeAll()
        
        print("🗑️ Cleared ALL template and schedule cache after deletion")
    }
    
    // MARK: - Schedule Endpoints
    func getSchedules(childId: String, date: Date) async throws -> [Schedule] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let cacheKey = getCacheKey(childId: childId, date: date)
        
        // Check cache first
        if let cached = scheduleCache[cacheKey], 
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            print("📦 Using cached schedules for child: \(childId), date: \(dateString)")
            return cached.schedules
        }
        
        print("🌐 Fetching fresh schedules for child: \(childId), date: \(dateString)")
        let response: SchedulesResponse = try await makeRequest("/schedules?childId=\(childId)&date=\(dateString)")
        
        // Cache the result
        scheduleCache[cacheKey] = (schedules: response.schedules, timestamp: Date())
        print("💾 Cached \(response.schedules.count) schedules for child: \(childId), date: \(dateString)")
        
        return response.schedules
    }

    // Bypass cache and always fetch fresh schedules
    func getSchedulesFresh(childId: String, date: Date) async throws -> [Schedule] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let cacheKey = getCacheKey(childId: childId, date: date)
        
        print("🌐 Fetching FRESH schedules for child: \(childId), date: \(dateString)")
        let response: SchedulesResponse = try await makeRequest("/schedules?childId=\(childId)&date=\(dateString)")
        
        // Update cache too
        scheduleCache[cacheKey] = (schedules: response.schedules, timestamp: Date())
        print("💾 Cached (fresh) \(response.schedules.count) schedules for child: \(childId), date: \(dateString)")
        
        return response.schedules
    }
    
    func generateSchedules(childId: String, dates: [Date]) async throws -> GenerateResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStrings = dates.map { dateFormatter.string(from: $0) }
        
        let request = GenerateSchedulesRequest(childId: childId, dates: dateStrings)
        let body = try JSONEncoder().encode(request)
        
        let response: GenerateResponse = try await makeRequest("/schedules/generate", method: "POST", body: body)
        
        // Clear ALL schedule cache to ensure fresh data
        scheduleCache.removeAll()
        print("🗑️ Cleared ALL schedule cache after generating schedules")
        
        // Small delay to ensure backend has processed the changes
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return response
    }
    
    func updateSchedule(id: String, updates: [String: Any]) async throws -> Schedule {
        let body = try JSONSerialization.data(withJSONObject: updates)
        return try await makeRequest("/schedules/\(id)", method: "PATCH", body: body)
    }

    // Delete a single scheduled instance
    func deleteSchedule(id: String) async throws {
        let _: EmptyResponse = try await makeRequest("/schedules/\(id)", method: "DELETE")
        // Clear schedule cache for safety
        scheduleCache.removeAll()
        print("🗑️ Cleared schedule cache after deleting schedule \(id)")
    }

    // Replace schedules over a time horizon (no templates)
    func replaceSchedules(childId: String, plan: [ReplacePlanItem], startDate: Date? = nil, weeks: Int = 8) async throws -> ReplacePlanResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let start = startDate != nil ? formatter.string(from: startDate!) : nil
        let request = ReplacePlanRequest(childId: childId, plan: plan, startDate: start, weeks: weeks)
        let body = try JSONEncoder().encode(request)
        
        // Simple retry with backoff for 429
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let response: ReplacePlanResponse = try await makeRequest("/schedules/replace", method: "POST", body: body)
                // Clear ALL schedule cache to ensure fresh data after replace
                scheduleCache.removeAll()
                print("🗑️ Cleared ALL schedule cache after replacing schedules")
                try await Task.sleep(nanoseconds: 300_000_000)
                return response
            } catch APIError.serverError(let code) where code == 429 {
                lastError = APIError.serverError(code)
                let delay = UInt64(500_000_000 * (attempt + 1))
                print("⏳ 429 received, backing off for \(Double(delay)/1_000_000_000)s (attempt \(attempt+1))")
                try await Task.sleep(nanoseconds: delay)
                continue
            } catch {
                lastError = error
                break
            }
        }
        throw lastError ?? APIError.serverError(429)
    }
    
    // MARK: - Child Endpoints
    func getChildren() async throws -> [Child] {
        let response: ChildrenResponse = try await makeRequest("/children")
        return response.children
    }
    
    func createChild(_ child: Child) async throws -> Child {
        let request = CreateChildRequest(
            firstName: child.firstName,
            lastName: child.lastName,
            dateOfBirth: child.dateOfBirth,
            gender: child.gender.rawValue,
            profileImageURL: child.profileImageURL
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(request)
        
        let response: ChildResponse = try await makeRequest("/children", method: "POST", body: body)
        return response.child
    }
    
    func updateChild(_ child: Child) async throws -> Child {
        let request = CreateChildRequest(
            firstName: child.firstName,
            lastName: child.lastName,
            dateOfBirth: child.dateOfBirth,
            gender: child.gender.rawValue,
            profileImageURL: child.profileImageURL
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(request)
        
        let response: ChildResponse = try await makeRequest("/children/\(child.id)", method: "PUT", body: body)
        return response.child
    }
    
    func deleteChild(_ childId: String) async throws {
        let _: EmptyResponse = try await makeRequest("/children/\(childId)", method: "DELETE")
    }
    
    func getFeedItems(childId: String) async throws -> [FeedItem] {
        let response: FeedItemsResponse = try await makeRequest("/feed?childId=\(childId)")
        return response.feedItems
    }
    
    func createFeedItem(_ feedItem: CreateFeedItemRequest) async throws -> FeedItem {
        let body = try JSONEncoder().encode(feedItem)
        let response: FeedItemResponse = try await makeRequest("/feed", method: "POST", body: body)
        return response.feedItem
    }
    
    func updateFeedItem(id: String, updates: UpdateFeedItemRequest) async throws -> FeedItem {
        let body = try JSONEncoder().encode(updates)
        let response: FeedItemResponse = try await makeRequest("/feed/\(id)", method: "PUT", body: body)
        return response.feedItem
    }
    
    func deleteFeedItem(id: String) async throws {
        let _: EmptyResponse = try await makeRequest("/feed/\(id)", method: "DELETE")
    }
    
    // MARK: - Caregiver Assignment
    func assignCaregiverToChild(caregiverEmail: String, childId: String) async throws {
        let body = try JSONEncoder().encode([
            "caregiverEmail": caregiverEmail
        ])
        
        let _: EmptyResponse = try await makeRequest("/users/caregivers/\(childId)", method: "POST", body: body)
    }
    
    // MARK: - Caregiver Management
    func getCaregivers() async throws -> [Caregiver] {
        let response: CaregiversResponse = try await makeRequest("/users/caregivers")
        return response.caregivers
    }
}

// MARK: - Response Models
struct AuthResponse: Codable {
    let message: String
    let user: User
    let token: String
}

struct TemplatesResponse: Codable {
    let templates: [ScheduleTemplate]
}

struct SchedulesResponse: Codable {
    let schedules: [Schedule]
}

struct BulkUpsertResponse: Codable {
    let results: [UpsertResult]
}

struct UpsertResult: Codable {
    let id: String
    let created: Bool
}

struct GenerateResponse: Codable {
    let results: [GenerateResult]
}

struct GenerateResult: Codable {
    let date: String
    let templateId: String
    let scheduleId: String
    let created: Bool
}

// MARK: - Child Response Models
struct ChildrenResponse: Codable {
    let children: [Child]
}

struct CaregiversResponse: Codable {
    let caregivers: [Caregiver]
}

struct ChildResponse: Codable {
    let message: String
    let child: Child
}

struct CreateChildRequest: Codable {
    let firstName: String
    let lastName: String
    let dateOfBirth: Date
    let gender: String
    let profileImageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case firstName = "firstName"
        case lastName = "lastName"
        case dateOfBirth = "dateOfBirth"
        case gender = "gender"
        case profileImageURL = "profileImageURL"
    }
}

struct EmptyResponse: Codable {
    // Empty response for DELETE operations
}

struct DeleteTemplateResponse: Codable {
    let message: String
    let childId: String
}

// MARK: - Feed Response Models
struct FeedItemsResponse: Codable {
    let feedItems: [FeedItem]
}

struct FeedItemResponse: Codable {
    let feedItem: FeedItem
}

struct CreateFeedItemRequest: Codable {
    let childId: String
    let title: String
    let content: String
    let contentType: String
    let mediaURLs: [String]
    let isPinned: Bool
    
    enum CodingKeys: String, CodingKey {
        case childId
        case title
        case content
        case contentType
        case mediaURLs
        case isPinned
    }
}

struct UpdateFeedItemRequest: Codable {
    let title: String?
    let content: String?
    let mediaURLs: [String]?
    let isPinned: Bool?
    
    enum CodingKeys: String, CodingKey {
        case title
        case content
        case mediaURLs
        case isPinned
    }
}

// MARK: - Request Models
struct TemplateItem: Codable {
    let title: String
    let type: String
    let description: String?
    let timeOfDay: String
    let frequency: String
    let weekday: Int?
    let notes: String?
}

struct BulkUpsertRequest: Codable {
    let childId: String
    let items: [TemplateItem]
}

struct GenerateSchedulesRequest: Codable {
    let childId: String
    let dates: [String]
}

// MARK: - Replace Plan Models (no templates)
struct ReplacePlanItem: Codable {
    let title: String
    let type: String
    let description: String?
    let timeOfDay: String // HH:mm:ss
    let weekdays: [Int]   // 1..7 (Sun=1)
    let notes: String?
}

struct ReplacePlanRequest: Codable {
    let childId: String
    let plan: [ReplacePlanItem]
    let startDate: String?
    let weeks: Int
}

struct ReplacePlanResponse: Codable {
    let deleted: Int
    let created: Int
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var currentCaregiver: Caregiver?
    @Published var biometricType: LABiometryType = .none
    @Published var isLoading = false
    @Published var authError: String?
    
    private let keychain = KeychainWrapper.standard
    private let biometricContext = LAContext()
    private let apiClient = APIClient.shared
    
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
        // Restore caregiver session if available (ensure JWT is set too)
        if let caregiverData = keychain.data(forKey: "currentCaregiver"),
           let caregiver = try? JSONDecoder().decode(Caregiver.self, from: caregiverData) {
            currentCaregiver = caregiver
            // IMPORTANT: Clear any parent session to avoid role confusion
            currentUser = nil
            if let token = keychain.string(forKey: "authToken") {
                apiClient.setAuthToken(token)
            }
            isAuthenticated = true
            print("✅ Restored existing session for caregiver: \(caregiver.email)")
            return
        }

        // Restore parent session if available (only if no caregiver session exists)
        if let userData = keychain.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            // IMPORTANT: Clear any caregiver session to avoid role confusion
            currentCaregiver = nil
            if let token = keychain.string(forKey: "authToken") {
                apiClient.setAuthToken(token)
            }
            isAuthenticated = true
            print("✅ Restored existing session for user: \(user.email)")
        }
    }
    
    func signIn(email: String, password: String) async -> Result<User, AuthError> {
        print("🔐 Attempting regular login for: \(email)")
        
        await MainActor.run {
            isLoading = true
            authError = nil
        }
        
        do {
            print("🔐 Attempting login for: \(email)")
            let response = try await apiClient.login(email: email, password: password)
            print("✅ Login successful for: \(email)")
            
            // Save to keychain
            // IMPORTANT: Clear any existing caregiver session to avoid role confusion
            keychain.removeObject(forKey: "currentCaregiver")
            if let userData = try? JSONEncoder().encode(response.user) {
                keychain.set(userData, forKey: "currentUser")
            }
            keychain.set(response.token, forKey: "authToken")
            
            await MainActor.run {
                // IMPORTANT: Clear currentCaregiver and set currentUser to avoid role confusion
                self.currentCaregiver = nil
                self.currentUser = response.user
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            return .success(response.user)
        } catch APIError.unauthorized {
            print("❌ Login failed: Unauthorized")
            await MainActor.run {
                self.authError = "Invalid email or password"
                self.isLoading = false
            }
            return .failure(.invalidCredentials)
        } catch APIError.decodingError {
            print("❌ Login failed: JSON decoding error")
            await MainActor.run {
                self.authError = "Invalid response format from server"
                self.isLoading = false
            }
            return .failure(.networkError)
        } catch let error as APIError {
            print("❌ Login failed with API error: \(error.localizedDescription)")
            await MainActor.run {
                self.authError = "Network error: \(error.localizedDescription)"
                self.isLoading = false
            }
            return .failure(.networkError)
        } catch {
            print("❌ Login failed with unknown error: \(error.localizedDescription)")
            await MainActor.run {
                self.authError = "Network error. Please try again"
                self.isLoading = false
            }
            return .failure(.networkError)
        }
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String, role: UserRole) async -> Result<User, AuthError> {
        await MainActor.run {
            isLoading = true
            authError = nil
        }
        
        do {
            let response = try await apiClient.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                role: role.rawValue
            )
            
            // Save to keychain
            // IMPORTANT: Clear any existing caregiver session to avoid role confusion
            keychain.removeObject(forKey: "currentCaregiver")
            if let userData = try? JSONEncoder().encode(response.user) {
                keychain.set(userData, forKey: "currentUser")
            }
            keychain.set(response.token, forKey: "authToken")
            
            await MainActor.run {
                // IMPORTANT: Clear currentCaregiver and set currentUser to avoid role confusion
                self.currentCaregiver = nil
                self.currentUser = response.user
                self.isAuthenticated = true
                self.isLoading = false
            }
            
            return .success(response.user)
        } catch {
            await MainActor.run {
                self.authError = "Registration failed. Please try again."
                self.isLoading = false
            }
            return .failure(.networkError)
        }
    }
    
    func signOut() {
        keychain.removeObject(forKey: "currentUser")
        keychain.removeObject(forKey: "currentCaregiver")
        keychain.removeObject(forKey: "authToken")
        apiClient.clearAuthToken()
        currentUser = nil
        currentCaregiver = nil
        isAuthenticated = false
    }
    
    // MARK: - Caregiver Authentication
    func signInAsCaregiver(email: String, password: String, dataManager: DataManager) async -> Result<Caregiver, AuthError> {
        print("🔐 Attempting caregiver login for: \(email)")
        
        // Authenticate against backend to obtain JWT, then bind to local caregiver profile
        await MainActor.run {
            isLoading = true
            authError = nil
        }

        do {
            // Login to backend to get JWT (caregiver should exist as a user with role "caregiver")
            let response = try await apiClient.login(email: email, password: password)

            // Persist JWT
            keychain.set(response.token, forKey: "authToken")

            // IMPORTANT: Clear any existing parent session to avoid role confusion
            keychain.removeObject(forKey: "currentUser")
            
            // Create caregiver profile from backend response
            let caregiver = Caregiver(
                id: response.user.id,
                email: response.user.email,
                firstName: response.user.firstName,
                lastName: response.user.lastName,
                role: .other, // Default role for caregivers
                createdBy: "", // Will be set when parent adds caregiver
                createdAt: response.user.createdAt,
                updatedAt: response.user.updatedAt,
                isActive: true
            )

            // Save caregiver to keychain for session restore
            if let caregiverData = try? JSONEncoder().encode(caregiver) {
                keychain.set(caregiverData, forKey: "currentCaregiver")
            }

            await MainActor.run {
                // IMPORTANT: Clear currentUser and set currentCaregiver to avoid role confusion
                self.currentUser = nil
                self.currentCaregiver = caregiver
                self.isAuthenticated = true
                self.isLoading = false
                print("✅ Caregiver session set: \(caregiver.email), currentUser: \(self.currentUser?.email ?? "nil"), currentCaregiver: \(self.currentCaregiver?.email ?? "nil")")
            }
            
            // Load the caregiver's assigned children from backend
            Task {
                await dataManager.loadChildrenFromBackend()
            }

            return .success(caregiver)
        } catch APIError.unauthorized {
            // Login failed, try to set up the caregiver account with new password
            do {
                // Try to set up the caregiver account with the new password
                let response = try await apiClient.setupCaregiverAccount(email: email, password: password)
                
                // Save session
                keychain.set(response.token, forKey: "authToken")
                // IMPORTANT: Clear any existing parent session to avoid role confusion
                keychain.removeObject(forKey: "currentUser")
                
                // Create caregiver profile from backend response
                let caregiver = Caregiver(
                    id: response.user.id,
                    email: response.user.email,
                    firstName: response.user.firstName,
                    lastName: response.user.lastName,
                    role: .other, // Default role for caregivers
                    createdBy: "", // Will be set when parent adds caregiver
                    createdAt: response.user.createdAt,
                    updatedAt: response.user.updatedAt,
                    isActive: true
                )
                
                if let caregiverData = try? JSONEncoder().encode(caregiver) {
                    keychain.set(caregiverData, forKey: "currentCaregiver")
                }
                
                await MainActor.run {
                    // IMPORTANT: Clear currentUser and set currentCaregiver to avoid role confusion
                    self.currentUser = nil
                    self.currentCaregiver = caregiver
                    self.isAuthenticated = true
                    self.isLoading = false
                    print("✅ Caregiver session set (setup): \(caregiver.email), currentUser: \(self.currentUser?.email ?? "nil"), currentCaregiver: \(self.currentCaregiver?.email ?? "nil")")
                }
                
                // Load the caregiver's assigned children from backend
                Task {
                    await dataManager.loadChildrenFromBackend()
                }
                
                return .success(caregiver)
            } catch {
                await MainActor.run {
                    self.authError = "Failed to set up caregiver account. Please try again."
                    self.isLoading = false
                }
                return .failure(.networkError)
            }
        } catch {
            await MainActor.run {
                self.authError = "Network error. Please try again"
                self.isLoading = false
            }
            return .failure(.networkError)
        }
    }
    
    func getAccessibleChildren(dataManager: DataManager) -> [Child] {
        if let caregiver = currentCaregiver {
            // For caregivers, return all children from dataManager since they were loaded from backend
            // The backend already filtered children that this caregiver has access to
            print("[Auth] getAccessibleChildren - caregiver mode, children count: \(dataManager.children.count), caregiver: \(caregiver.email)")
            return dataManager.children
        } else if let user = currentUser {
            print("[Auth] getAccessibleChildren - parent mode, children count: \(dataManager.children.count), user: \(user.email)")
            return dataManager.children.filter { $0.parentId == user.id }
        }
        print("[Auth] getAccessibleChildren - no user, returning empty")
        return []
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
    
    // MARK: - Caregiver Management API
    func createCaregiverAccount(email: String, password: String, firstName: String, lastName: String) async throws -> User {
        // Store the current token to restore it later
        let currentToken = apiClient.getAuthToken()
        
        let response = try await apiClient.register(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: "caregiver"
        )
        
        // Restore the parent's token (don't switch to caregiver token)
        if let token = currentToken {
            apiClient.setAuthToken(token)
        }
        
        return response.user
    }
    
    func assignCaregiverToChild(caregiverId: String, childId: String) async throws {
        try await apiClient.assignCaregiverToChild(caregiverEmail: caregiverId, childId: childId)
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
    
    func string(forKey key: String) -> String? {
        guard let data = data(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func set(_ string: String, forKey key: String) {
        guard let data = string.data(using: .utf8) else { return }
        set(data, forKey: key)
    }
    
    func removeObject(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
} 