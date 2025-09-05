import Foundation
import SwiftUI

enum ScheduleType: String, CaseIterable, Codable, Equatable {
    case medicine = "medicine"
    case feeding = "feeding"
    case milk = "milk"
    case nap = "nap"
    case diaper = "diaper"
    case bath = "bath"
    case play = "play"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .medicine:
            return "Medicine"
        case .feeding:
            return "Feeding"
        case .milk:
            return "Milk"
        case .nap:
            return "Nap"
        case .diaper:
            return "Diaper"
        case .bath:
            return "Bath"
        case .play:
            return "Play"
        case .other:
            return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .medicine:
            return "💊"
        case .feeding:
            return "🍽️"
        case .milk:
            return "🥛"
        case .nap:
            return "😴"
        case .diaper:
            return "👶"
        case .bath:
            return "🛁"
        case .play:
            return "🎮"
        case .other:
            return "📝"
        }
    }
    
    var color: Color {
        switch self {
        case .medicine:
            return .red
        case .feeding:
            return .orange
        case .milk:
            return .blue
        case .nap:
            return .purple
        case .diaper:
            return .green
        case .bath:
            return .cyan
        case .play:
            return .pink
        case .other:
            return .gray
        }
    }
}

enum ScheduleFrequency: String, CaseIterable, Codable, Equatable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
    
    var icon: String {
        switch self {
        case .daily:
            return "📅"
        case .weekly:
            return "📆"
        case .monthly:
            return "🗓️"
        }
    }
}

enum ScheduleStatus: String, CaseIterable, Codable, Equatable {
    case scheduled = "scheduled"
    case inProgress = "in_progress"
    case completed = "completed"
    case missed = "missed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .missed:
            return "Missed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .scheduled:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        case .missed:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .scheduled:
            return "⏰"
        case .inProgress:
            return "🔄"
        case .completed:
            return "✅"
        case .missed:
            return "❌"
        case .cancelled:
            return "🚫"
        }
    }
}

// MARK: - Schedule Template (for recurring schedules)
struct ScheduleTemplate: Identifiable, Codable, Equatable {
    let id: String
    let childId: String
    let name: String
    let type: ScheduleType
    let title: String
    let description: String?
    let timeOfDay: Date // Just the time component
    let frequency: ScheduleFrequency
    let weekday: Int? // Added to match backend API
    let notes: String?
    let createdBy: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String = UUID().uuidString,
         childId: String,
         name: String,
         type: ScheduleType,
         title: String,
         description: String? = nil,
         timeOfDay: Date,
         frequency: ScheduleFrequency = .daily,
         weekday: Int? = nil,
         notes: String? = nil,
         createdBy: String,
         isActive: Bool = true,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.childId = childId
        self.name = name
        self.type = type
        self.title = title
        self.description = description
        self.timeOfDay = timeOfDay
        self.frequency = frequency
        self.weekday = weekday
        self.notes = notes
        self.createdBy = createdBy
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timeOfDay)
    }
    
    // Custom decoder to handle backend field mapping
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        childId = try container.decode(String.self, forKey: .childId)
        type = try container.decode(ScheduleType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        frequency = try container.decode(ScheduleFrequency.self, forKey: .frequency)
        weekday = try container.decodeIfPresent(Int.self, forKey: .weekday)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        
        // Parse timeOfDay from string
        let timeString = try container.decode(String.self, forKey: .timeOfDay)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        guard let time = formatter.date(from: timeString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid time format")
        }
        timeOfDay = time
        
        // Parse dates
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let createdAt = dateFormatter.date(from: createdAtString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid createdAt date format")
        }
        guard let updatedAt = dateFormatter.date(from: updatedAtString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid updatedAt date format")
        }
        
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        // Map title to name for backward compatibility
        name = title
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case type
        case title
        case description
        case timeOfDay = "time_of_day"
        case frequency
        case weekday
        case notes
        case createdBy = "created_by"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Daily Schedule Instance
struct Schedule: Identifiable, Codable, Equatable {
    let id: String
    let templateId: String? // If null, this is a one-time schedule
    let childId: String
    let type: ScheduleType
    let title: String
    let description: String?
    let scheduledTime: Date
    let status: ScheduleStatus
    let notes: String?
    let createdBy: String
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    var timeUntilScheduled: TimeInterval {
        scheduledTime.timeIntervalSinceNow
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: scheduledTime)
    }
    
    // Create from template
    init(from template: ScheduleTemplate, for date: Date) {
        let calendar = Calendar.current
        let templateTime = calendar.dateComponents([.hour, .minute], from: template.timeOfDay)
        let scheduledTime = calendar.date(bySettingHour: templateTime.hour ?? 0, minute: templateTime.minute ?? 0, second: 0, of: date) ?? date
        
        self.id = UUID().uuidString
        self.templateId = template.id
        self.childId = template.childId
        self.type = template.type
        self.title = template.title
        self.description = template.description
        self.scheduledTime = scheduledTime
        self.status = .scheduled
        self.notes = template.notes
        self.createdBy = template.createdBy
        self.completedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Create one-time schedule
    init(id: String = UUID().uuidString,
         childId: String,
         type: ScheduleType,
         title: String,
         description: String? = nil,
         scheduledTime: Date,
         status: ScheduleStatus = .scheduled,
         notes: String? = nil,
         createdBy: String,
         completedAt: Date? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.templateId = nil
        self.childId = childId
        self.type = type
        self.title = title
        self.description = description
        self.scheduledTime = scheduledTime
        self.status = status
        self.notes = notes
        self.createdBy = createdBy
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Core Data Schedule Entity - Commented out until Core Data is properly set up
/*
extension ScheduleEntity {
    var schedule: Schedule {
        Schedule(
            id: id ?? UUID().uuidString,
            childId: childId ?? "",
            type: ScheduleType(rawValue: type ?? "other") ?? .other,
            title: title ?? "",
            description: description,
            scheduledTime: scheduledTime ?? Date(),
            status: ScheduleStatus(rawValue: status ?? "scheduled") ?? .scheduled,
            notes: notes,
            createdBy: createdBy ?? "",
            completedAt: completedAt,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
    
    func update(from schedule: Schedule) {
        self.id = schedule.id
        self.childId = schedule.childId
        self.type = schedule.type.rawValue
        self.title = schedule.title
        self.description = schedule.description
        self.scheduledTime = schedule.scheduledTime
        self.status = schedule.status.rawValue
        self.notes = schedule.notes
        self.createdBy = schedule.createdBy
        self.completedAt = schedule.completedAt
        self.updatedAt = Date()
    }
}
*/ 