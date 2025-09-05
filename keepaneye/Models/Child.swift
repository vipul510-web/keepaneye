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
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
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