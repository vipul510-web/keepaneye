import Foundation
import Combine

class DataManager: ObservableObject {
    @Published var children: [Child] = []
    @Published var schedules: [Schedule] = []
    @Published var scheduleTemplates: [ScheduleTemplate] = []
    @Published var users: [User] = []
    
    // Helper: Extract target weekday from template notes if present
    private func weekdayFromNotes(_ notes: String?) -> Int? {
        guard let notes else { return nil }
        if let range = notes.range(of: "weekday=") {
            let value = String(notes[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let n = Int(value) { return n }
        }
        if notes.contains("weekday ") {
            let parts = notes.split(separator: " ")
            if let last = parts.last, let n = Int(last) { return n }
        }
        return nil
    }
    
    // Public: Find an existing weekly template for a child/week day/time/type/title (hour+minute match)
    func findWeeklyTemplate(childId: String, weekday: Int, time: Date, title: String, type: ScheduleType) -> ScheduleTemplate? {
        let cal = Calendar.current
        let targetHM = cal.dateComponents([.hour, .minute], from: time)
        return scheduleTemplates.first(where: { tpl in
            tpl.childId == childId &&
            tpl.frequency == .weekly &&
            weekdayFromNotes(tpl.notes) == weekday &&
            tpl.type == type &&
            tpl.title == title &&
            cal.dateComponents([.hour, .minute], from: tpl.timeOfDay) == targetHM
        })
    }
    
    // Public: All weekdays that have weekly templates for a child
    func configuredWeekdays(for childId: String) -> Set<Int> {
        var set: Set<Int> = []
        for tpl in scheduleTemplates where tpl.childId == childId && tpl.frequency == .weekly {
            if let w = weekdayFromNotes(tpl.notes) { set.insert(w) }
        }
        return set
    }

    init() {
        loadMockData()
    }
    
    // MARK: - Mock Data Loading
    private func loadMockData() {
        // Create mock children
        let mockChild = Child(
            firstName: "Emma",
            lastName: "Smith",
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(),
            gender: .female,
            parentId: "parent1"
        )
        
        children = [mockChild]
        
        // Create mock schedule templates
        let breakfastTemplate = ScheduleTemplate(
            childId: mockChild.id,
            name: "Daily Breakfast",
            type: .feeding,
            title: "Breakfast",
            description: "Morning meal",
            timeOfDay: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
            frequency: .daily,
            createdBy: "parent1"
        )
        
        let napTemplate = ScheduleTemplate(
            childId: mockChild.id,
            name: "Afternoon Nap",
            type: .nap,
            title: "Nap Time",
            description: "Afternoon rest",
            timeOfDay: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date(),
            frequency: .daily,
            createdBy: "parent1"
        )
        
        let weeklyBathTemplate = ScheduleTemplate(
            childId: mockChild.id,
            name: "Weekly Bath",
            type: .bath,
            title: "Bath Time",
            description: "Weekly bath routine",
            timeOfDay: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date(),
            frequency: .weekly,
            createdBy: "parent1",
            notes: "weekday=2"
        )
        
        scheduleTemplates = [breakfastTemplate, napTemplate, weeklyBathTemplate]
        
        // Generate today's schedules from templates
        generateDailySchedules(for: Date())
    }
    
    // MARK: - Schedule Template Management
    func addScheduleTemplate(_ template: ScheduleTemplate) {
        scheduleTemplates.append(template)
        generateDailySchedules(for: Date()) // Regenerate today's schedules
    }
    
    func updateScheduleTemplate(_ template: ScheduleTemplate) {
        if let index = scheduleTemplates.firstIndex(where: { $0.id == template.id }) {
            scheduleTemplates[index] = template
            generateDailySchedules(for: Date()) // Regenerate today's schedules
        }
    }
    
    func deleteScheduleTemplate(_ template: ScheduleTemplate) {
        scheduleTemplates.removeAll { $0.id == template.id }
        // Remove all schedules generated from this template
        schedules.removeAll { $0.templateId == template.id }
    }
    
    // MARK: - Daily Schedule Generation
    func generateDailySchedules(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Remove existing schedules for this date (but keep one-time schedules)
        schedules.removeAll { schedule in
            schedule.scheduledTime >= startOfDay && 
            schedule.scheduledTime < endOfDay && 
            schedule.templateId != nil
        }
        
        // Generate new schedules from active templates based on frequency
        for template in scheduleTemplates where template.isActive {
            if shouldGenerateSchedule(for: template, on: date) {
                let schedule = Schedule(from: template, for: date)
                schedules.append(schedule)
            }
        }
    }
    
    private func shouldGenerateSchedule(for template: ScheduleTemplate, on date: Date) -> Bool {
        let calendar = Calendar.current
        
        switch template.frequency {
        case .daily:
            return true // Always generate for daily routines
            
        case .weekly:
            // Check weekday field if present, else fall back to createdAt weekday
            if let target = template.weekday {
                let dateWeekday = calendar.component(.weekday, from: date)
                return target == dateWeekday
            }
            let templateWeekday = calendar.component(.weekday, from: template.createdAt)
            let dateWeekday = calendar.component(.weekday, from: date)
            return templateWeekday == dateWeekday
            
        case .monthly:
            // Generate on the same day of the month as the template was created
            let templateDay = calendar.component(.day, from: template.createdAt)
            let dateDay = calendar.component(.day, from: date)
            return templateDay == dateDay
        }
    }
    
    // MARK: - Child Management
    func addChild(_ child: Child) {
        children.append(child)
    }
    
    func updateChild(_ child: Child) {
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = child
        }
    }
    
    func deleteChild(_ child: Child) {
        children.removeAll { $0.id == child.id }
        // Also remove related schedules and templates
        schedules.removeAll { $0.childId == child.id }
        scheduleTemplates.removeAll { $0.childId == child.id }
    }
    
    // MARK: - Schedule Management
    func addSchedule(_ schedule: Schedule) {
        schedules.append(schedule)
    }
    
    func updateSchedule(_ schedule: Schedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        }
    }
    
    func deleteSchedule(_ schedule: Schedule) {
        schedules.removeAll { $0.id == schedule.id }
    }
    
    func getSchedules(for childId: String, on date: Date? = nil) -> [Schedule] {
        var filteredSchedules = schedules.filter { $0.childId == childId }
        
        if let date = date {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            filteredSchedules = filteredSchedules.filter { schedule in
                schedule.scheduledTime >= startOfDay && schedule.scheduledTime < endOfDay
            }
        }
        
        return filteredSchedules.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    func getScheduleTemplates(for childId: String) -> [ScheduleTemplate] {
        return scheduleTemplates.filter { $0.childId == childId && $0.isActive }
    }
    
    // MARK: - User Management
    func addUser(_ user: User) {
        users.append(user)
    }
    
    func updateUser(_ user: User) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        }
    }
    
    func getUser(by id: String) -> User? {
        return users.first { $0.id == id }
    }
    
    // MARK: - Data Persistence (Mock)
    func save() {
        // In a real app, this would save to Core Data or backend
        print("✅ Data saved (mock)")
    }
    
    func load() {
        // In a real app, this would load from Core Data or backend
        loadMockData()
    }
} 