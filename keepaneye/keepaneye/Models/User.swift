import Foundation

enum UserRole: String, CaseIterable, Codable, Equatable {
    case parent = "parent"
    case caregiver = "caregiver"
    
    var displayName: String {
        switch self {
        case .parent:
            return "Parent"
        case .caregiver:
            return "Caregiver"
        }
    }
    
    var canAddCaregivers: Bool {
        return self == .parent
    }
    
    var emoji: String {
        switch self {
        case .parent:
            return "👨‍👩‍👧‍👦"
        case .caregiver:
            return "👩‍⚕️"
        }
    }
}

struct User: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let role: UserRole
    let profileImageURL: String?
    let createdAt: Date
    let updatedAt: Date
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var displayName: String {
        "\(firstName) \(lastName) (\(role.displayName))"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case role
        case profileImageURL = "profile_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        role = try container.decode(UserRole.self, forKey: .role)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        
        // Decode dates from ISO 8601 strings
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let createdAtDate = dateFormatter.date(from: createdAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Invalid date format")
        }
        
        guard let updatedAtDate = dateFormatter.date(from: updatedAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: container, debugDescription: "Invalid date format")
        }
        
        createdAt = createdAtDate
        updatedAt = updatedAtDate
    }
    
    init(id: String = UUID().uuidString,
         email: String,
         firstName: String,
         lastName: String,
         role: UserRole,
         profileImageURL: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
        self.profileImageURL = profileImageURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Core Data User Entity - Commented out until Core Data is properly set up
/*
extension UserEntity {
    var user: User {
        User(
            id: id ?? UUID().uuidString,
            email: email ?? "",
            firstName: firstName ?? "",
            lastName: lastName ?? "",
            role: UserRole(rawValue: role ?? "caregiver") ?? .caregiver,
            profileImageURL: profileImageURL,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
    
    func update(from user: User) {
        self.id = user.id
        self.email = user.email
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.role = user.role.rawValue
        self.profileImageURL = user.profileImageURL
        self.updatedAt = Date()
    }
}
*/ 