import UserNotifications
import SwiftUI

@Observable
final class NotificationManager {
    
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    
    private(set) var authorizationStatus: UNAuthorizationStatus?
    
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "steady_notifications_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "steady_notifications_enabled")
            if newValue {
                requestAuthorization()
            } else {
                cancelAll()
            }
        }
    }
    
    var dailyReminderTime: Date {
        get {
            if let saved = UserDefaults.standard.object(forKey: "steady_reminder_time") as? Date {
                return saved
            }
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "steady_reminder_time")
            rescheduleAll(premium: false)
        }
    }
    
    private var habits: [Habit] = []
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.checkAuthorizationStatus()
                if granted {
                    self.rescheduleAll(premium: false)
                }
            }
        }
    }
    
    func updateHabits(_ habits: [Habit]) {
        self.habits = habits
    }
    
    func rescheduleAll(premium: Bool) {
        guard isEnabled, authorizationStatus == .authorized else {
            cancelAll()
            return
        }
        
        cancelAll()
        
        if premium {
            schedulePremiumNotifications()
        } else {
            scheduleFreeNotifications()
        }
    }
    
    private func scheduleFreeNotifications() {
        let content = UNMutableNotificationContent()
        content.title = "Steady"
        content.body = "N'oublie pas de valider tes habitudes aujourd'hui. Chaque petit pas compte !"
        content.sound = .default
        content.categoryIdentifier = "steady_daily_reminder"
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: dailyReminderTime)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "steady_free_daily", content: content, trigger: trigger)
        
        center.add(request)
    }
    
    private func schedulePremiumNotifications() {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: dailyReminderTime)
        
        for index in 0..<min(habits.count, 3) {
            let habit = habits[index]
            let content = UNMutableNotificationContent()
            content.title = "Steady"
            content.body = "C'est l'heure de \(habit.name). Tu l'as validée \(weeklyStreak(for: habit)) fois cette semaine !"
            content.sound = .default
            content.categoryIdentifier = "steady_habit_reminder"
            content.userInfo = ["habit_id": habit.id.uuidString]
            
            var components = timeComponents
            components.minute = (components.minute ?? 0) + (index * 2)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "steady_premium_habit_\(index)", content: content, trigger: trigger)
            center.add(request)
        }
        
        var sundayComponents = timeComponents
        sundayComponents.weekday = 1
        sundayComponents.hour = 19
        sundayComponents.minute = 0
        
        let weeklyContent = UNMutableNotificationContent()
        weeklyContent.title = "Ton résumé de la semaine"
        weeklyContent.body = weeklySummaryBody()
        weeklyContent.sound = .default
        weeklyContent.categoryIdentifier = "steady_weekly_summary"
        
        let weeklyTrigger = UNCalendarNotificationTrigger(dateMatching: sundayComponents, repeats: true)
        let weeklyRequest = UNNotificationRequest(identifier: "steady_premium_weekly", content: weeklyContent, trigger: weeklyTrigger)
        center.add(weeklyRequest)
        
        if hasSevenDayStreak() {
            let streakContent = UNMutableNotificationContent()
            streakContent.title = "Streak parfait !"
            streakContent.body = "7 jours consécutifs. Tu es sur une excellente lancée, félicitations !"
            streakContent.sound = .default
            streakContent.categoryIdentifier = "steady_streak"
            
            let streakTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            let streakRequest = UNNotificationRequest(identifier: "steady_premium_streak", content: streakContent, trigger: streakTrigger)
            center.add(streakRequest)
        }
    }
    
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    private func weeklyStreak(for habit: Habit) -> Int {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return habit.records.filter { $0.date >= weekAgo && $0.status == .completed }.count
    }
    
    private func hasSevenDayStreak() -> Bool {
        let calendar = Calendar.current
        for habit in habits {
            let last7 = (0..<7).compactMap { day -> Date? in
                calendar.date(byAdding: .day, value: -day, to: calendar.startOfDay(for: Date()))
            }
            let allCompleted = last7.allSatisfy { date in
                habit.records.contains {
                    calendar.isDate($0.date, inSameDayAs: date) && $0.status == .completed
                }
            }
            if allCompleted { return true }
        }
        return false
    }
    
    private func weeklySummaryBody() -> String {
        let total = habits.reduce(0) { $0 + weeklyStreak(for: $1) }
        if total == 0 {
            return "Cette semaine était calme. Pas de souci, on reprend doucement lundi."
        } else if total < 10 {
            return "Belle semaine ! Tu as validé \(total) habitudes au total. Continue sur cette lancée."
        } else {
            return "Semaine exceptionnelle : \(total) validations. Tu progresses visiblement !"
        }
    }
}
