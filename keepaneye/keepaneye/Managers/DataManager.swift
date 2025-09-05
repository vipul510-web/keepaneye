import Foundation
import Combine

class DataManager: ObservableObject {
    @Published var children: [Child] = []
    @Published var schedules: [Schedule] = []
    @Published var scheduleTemplates: [ScheduleTemplate] = []
    @Published var users: [User] = []
    @Published var caregivers: [Caregiver] = []
    @Published var isLoadingChildren: Bool = false
    
    private let apiClient = APIClient.shared
    
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
        // Start with empty data - will be loaded from backend after authentication
        print("📱 DataManager initialized with empty data")
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
        print("🔄 Generating daily schedules for: \(date)")
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let beforeCount = schedules.count
        
        // Remove existing schedules for this date (but keep one-time schedules and modified schedules)
        let schedulesToRemove = schedules.filter { schedule in
            schedule.scheduledTime >= startOfDay && 
            schedule.scheduledTime < endOfDay && 
            schedule.templateId != nil &&
            !schedule.hasBeenModified // Don't remove modified schedules
        }
        
        print("🔍 Found \(schedulesToRemove.count) schedules to remove")
        for schedule in schedulesToRemove {
            print("   - Removing: \(schedule.title) (modified: \(schedule.hasBeenModified))")
        }
        
        schedules.removeAll { schedule in
            schedule.scheduledTime >= startOfDay && 
            schedule.scheduledTime < endOfDay && 
            schedule.templateId != nil &&
            !schedule.hasBeenModified // Don't remove modified schedules
        }
        
        let afterRemovalCount = schedules.count
        print("🗑️ Removed \(beforeCount - afterRemovalCount) schedules")
        
        // Generate new schedules from active templates based on frequency
        for template in scheduleTemplates where template.isActive {
            if shouldGenerateSchedule(for: template, on: date) {
                // Check if we already have ANY schedule for this template on this date (modified or not)
                let existingSchedule = schedules.first { schedule in
                    schedule.scheduledTime >= startOfDay && 
                    schedule.scheduledTime < endOfDay && 
                    schedule.templateId == template.id
                }
                
                if let existing = existingSchedule {
                    print("⏭️ Skipped creating schedule for template: \(template.name) (schedule already exists: \(existing.title) - Modified: \(existing.hasBeenModified))")
                } else {
                    let schedule = Schedule(from: template, for: date)
                    schedules.append(schedule)
                    print("➕ Created new schedule: \(schedule.title)")
                }
            }
        }
        
        print("📊 Final schedule count: \(schedules.count)")
        
        // Debug: Show all schedules for this date
        let dateSchedules = schedules.filter { schedule in
            schedule.scheduledTime >= startOfDay && 
            schedule.scheduledTime < endOfDay
        }
        print("📅 Schedules for \(date):")
        for schedule in dateSchedules {
            print("   - \(schedule.title) (ID: \(schedule.id), Modified: \(schedule.hasBeenModified), Template: \(schedule.templateId ?? "none"))")
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
        
        // Clear mock data when adding a real child
        if !children.isEmpty {
            scheduleTemplates = []
            schedules = []
            print("🗑️ Cleared mock data since we're adding a real child")
        }
        
        // Also save to backend
        Task {
            do {
                let savedChild = try await apiClient.createChild(child)
                print("✅ Child saved to backend: \(savedChild.fullName)")
                // Update the local child with the backend ID
                await MainActor.run {
                    if let index = children.firstIndex(where: { $0.id == child.id }) {
                        children[index] = savedChild
                    }
                }
            } catch {
                print("❌ Failed to save child to backend: \(error)")
            }
        }
    }
    
    func updateChild(_ child: Child) {
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = child
        }
        
        // Also update in backend
        Task {
            do {
                let updatedChild = try await apiClient.updateChild(child)
                print("✅ Child updated in backend: \(updatedChild.fullName)")
                // Update the local child with the backend data
                await MainActor.run {
                    if let index = children.firstIndex(where: { $0.id == child.id }) {
                        children[index] = updatedChild
                    }
                }
            } catch {
                print("❌ Failed to update child in backend: \(error)")
            }
        }
    }
    
    func deleteChild(_ child: Child) {
        children.removeAll { $0.id == child.id }
        // Also remove related schedules and templates
        schedules.removeAll { $0.childId == child.id }
        scheduleTemplates.removeAll { $0.childId == child.id }
        
        // Also delete from backend
        Task {
            do {
                try await apiClient.deleteChild(child.id)
                print("✅ Child deleted from backend: \(child.fullName)")
            } catch {
                print("❌ Failed to delete child from backend: \(error)")
            }
        }
    }
    
    func loadChildrenFromBackend() async {
        // Set loading state
        await MainActor.run {
            self.isLoadingChildren = true
            print("🔄 Loading children from backend...")
        }
        
        do {
            let backendChildren = try await apiClient.getChildren()
            await MainActor.run {
                // Replace with backend data
                self.children = backendChildren
                self.isLoadingChildren = false
                print("✅ Loaded \(backendChildren.count) children from backend")
                print("📊 Current DataManager children count: \(self.children.count)")
            }
        } catch {
            await MainActor.run {
                self.isLoadingChildren = false
                print("❌ Failed to load children from backend: \(error)")
            }
        }
    }
    
    // Public method to refresh children from backend
    func refreshChildren() async {
        await loadChildrenFromBackend()
    }
    
    // Public method to load caregivers from backend
    func loadCaregiversFromBackend() async {
        // Only load caregivers if the current user is a parent
        // Note: This method should be called from a context where we have access to AuthenticationManager
        // For now, we'll skip the check and let the backend handle authorization
        do {
            let backendCaregivers = try await APIClient.shared.getCaregivers()
            
            await MainActor.run {
                self.caregivers = backendCaregivers
                print("✅ Loaded \(backendCaregivers.count) caregivers from backend")
            }
        } catch {
            print("❌ Failed to load caregivers from backend: \(error)")
        }
    }
    
    // MARK: - Schedule Management
    func addSchedule(_ schedule: Schedule) {
        schedules.append(schedule)
    }
    
    func updateSchedule(_ schedule: Schedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            print("📝 Updating schedule: \(schedule.title) (ID: \(schedule.id), Modified: \(schedule.hasBeenModified), Template: \(schedule.templateId ?? "none"))")
            schedules[index] = schedule
        } else {
            print("⚠️ Schedule not found for update: \(schedule.title) (ID: \(schedule.id))")
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
    
    // MARK: - Caregiver Management
    func addCaregiver(_ caregiver: Caregiver) {
        caregivers.append(caregiver)
    }
    
    func updateCaregiver(_ caregiver: Caregiver) {
        if let index = caregivers.firstIndex(where: { $0.id == caregiver.id }) {
            caregivers[index] = caregiver
        }
    }
    
    func deleteCaregiver(_ caregiver: Caregiver) {
        caregivers.removeAll { $0.id == caregiver.id }
    }
    
    func getCaregivers(for parentId: String) -> [Caregiver] {
        return caregivers.filter { $0.createdBy == parentId && $0.isActive }
    }
    
    func getCaregiversForChild(_ childId: String) -> [Caregiver] {
        return caregivers.filter { $0.assignedChildIds.contains(childId) && $0.isActive }
    }
    
    func getChildrenForCaregiver(_ caregiverId: String) -> [Child] {
        guard let caregiver = caregivers.first(where: { $0.id == caregiverId }) else {
            return []
        }
        return children.filter { caregiver.assignedChildIds.contains($0.id) }
    }
    
    // MARK: - Data Persistence (Mock)
    func save() {
        // In a real app, this would save to Core Data or backend
        print("✅ Data saved (mock)")
    }
    
    func load() {
        // In a real app, this would load from Core Data or backend
        // For now, we load from backend via loadChildrenFromBackend()
        print("📱 Data load requested - will load from backend when needed")
    }
} 