import Foundation

enum Gender: String, CaseIterable, Codable, Equatable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .other:
            return "Other"
        case .preferNotToSay:
            return "Prefer not to say"
        }
    }
    
    var emoji: String {
        switch self {
        case .male:
            return "👦"
        case .female:
            return "👧"
        case .other:
            return "👤"
        case .preferNotToSay:
            return "🤷"
        }
    }
}

struct Child: Identifiable, Codable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let dateOfBirth: Date
    let gender: Gender
    let parentId: String
    let caregiverIds: [String]
    let profileImageURL: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case gender
        case parentId = "parent_id"
        case caregiverIds = "caregiver_ids"
        case profileImageURL = "profile_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        gender = try container.decode(Gender.self, forKey: .gender)
        parentId = try container.decode(String.self, forKey: .parentId)
        caregiverIds = try container.decode([String].self, forKey: .caregiverIds)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        
        // Decode dateOfBirth from ISO 8601 string
        let dateOfBirthString = try container.decode(String.self, forKey: .dateOfBirth)
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let dateOfBirthDate = dateFormatter.date(from: dateOfBirthString) else {
            throw DecodingError.dataCorruptedError(forKey: .dateOfBirth, in: container, debugDescription: "Invalid date format")
        }
        
        guard let createdAtDate = dateFormatter.date(from: createdAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Invalid date format")
        }
        
        guard let updatedAtDate = dateFormatter.date(from: updatedAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: container, debugDescription: "Invalid date format")
        }
        
        dateOfBirth = dateOfBirthDate
        createdAt = createdAtDate
        updatedAt = updatedAtDate
    }
    
    var ageDescription: String {
        if age == 0 {
            let months = Calendar.current.dateComponents([.month], from: dateOfBirth, to: Date()).month ?? 0
            if months == 0 {
                let days = Calendar.current.dateComponents([.day], from: dateOfBirth, to: Date()).day ?? 0
                return "\(days) day\(days == 1 ? "" : "s")"
            }
            return "\(months) month\(months == 1 ? "" : "s")"
        }
        return "\(age) year\(age == 1 ? "" : "s")"
    }
    
    init(id: String = UUID().uuidString,
         firstName: String,
         lastName: String,
         dateOfBirth: Date,
         gender: Gender,
         parentId: String,
         profileImageURL: String? = nil,
         caregiverIds: [String] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.parentId = parentId
        self.profileImageURL = profileImageURL
        self.caregiverIds = caregiverIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Core Data Child Entity - Commented out until Core Data is properly set up
/*
extension ChildEntity {
    var child: Child {
        Child(
            id: id ?? UUID().uuidString,
            firstName: firstName ?? "",
            lastName: lastName ?? "",
            dateOfBirth: dateOfBirth ?? Date(),
            gender: Gender(rawValue: gender ?? "other") ?? .other,
            parentId: parentId ?? "",
            profileImageURL: profileImageURL,
            caregiverIds: caregiverIds?.components(separatedBy: ",") ?? [],
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
    
    func update(from child: Child) {
        self.id = child.id
        self.firstName = child.firstName
        self.lastName = child.lastName
        self.dateOfBirth = child.dateOfBirth
        self.gender = child.gender.rawValue
        self.parentId = child.parentId
        self.profileImageURL = child.profileImageURL
        self.caregiverIds = child.caregiverIds.joined(separator: ",")
        self.updatedAt = Date()
    }
}
*/ 