import UserNotifications
import SwiftUI

@MainActor
@Observable
final class NotificationManager {
    
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    
    private(set) var authorizationStatus: UNAuthorizationStatus?

    /// Propriétés STOCKÉES (observables) : toute modification est détectée par
    /// SwiftUI immédiatement — plus besoin de relancer l'app pour voir le changement.
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "steady_notifications_enabled")
            if isEnabled {
                requestAuthorization()
            } else {
                cancelAll()
            }
        }
    }

    /// Le « rappel quotidien » général (indépendant des rappels par habitude).
    var dailyReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dailyReminderEnabled, forKey: "steady_daily_reminder_enabled")
            rescheduleAll(premium: lastKnownPremium)
        }
    }

    var dailyReminderTime: Date {
        didSet {
            UserDefaults.standard.set(dailyReminderTime, forKey: "steady_reminder_time")
            rescheduleAll(premium: lastKnownPremium)
        }
    }

    private var lastKnownPremium = false
    private var habits: [Habit] = []

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "steady_notifications_enabled")
        self.dailyReminderEnabled = UserDefaults.standard.object(forKey: "steady_daily_reminder_enabled") as? Bool ?? true
        if let saved = UserDefaults.standard.object(forKey: "steady_reminder_time") as? Date {
            self.dailyReminderTime = saved
        } else {
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            self.dailyReminderTime = Calendar.current.date(from: components) ?? Date()
        }
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        Task { @MainActor in
            let settings = await center.notificationSettings()
            self.authorizationStatus = settings.authorizationStatus
        }
    }

    func requestAuthorization() {
        Task { @MainActor in
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                let settings = await center.notificationSettings()
                self.authorizationStatus = settings.authorizationStatus
                if granted {
                    self.rescheduleAll(premium: self.lastKnownPremium)
                }
            } catch {}
        }
    }
    
    func updateHabits(_ habits: [Habit]) {
        self.habits = habits
    }
    
    func rescheduleAll(premium: Bool) {
        lastKnownPremium = premium
        guard isEnabled, authorizationStatus == .authorized else {
            cancelAll()
            return
        }

        cancelAll()

        // 1) Rappels propres à chaque habitude (chacun à son heure).
        scheduleHabitReminders()

        // 2) Le rappel quotidien général, s'il est activé (indépendant des rappels par habitude).
        if dailyReminderEnabled {
            scheduleGlobalDaily()
        }

        // 3) Bilan du dimanche soir (pour tout le monde).
        scheduleWeeklyDigest()

        // 4) Petit check du soir : seulement s'il reste des habitudes à valider.
        scheduleEveningCheck()
    }

    // MARK: - Rappels par habitude (heure individuelle)

    @discardableResult
    private func scheduleHabitReminders() -> Int {
        let calendar = Calendar.current
        var count = 0
        for habit in habits where habit.reminderEnabled {
            guard let time = habit.reminderTime else { continue }
            let hm = calendar.dateComponents([.hour, .minute], from: time)

            let content = UNMutableNotificationContent()
            content.title = "Steady"
            content.body = L("C'est l'heure de \(habit.name) 🌿")
            content.sound = .default
            content.categoryIdentifier = "steady_habit_reminder"
            content.userInfo = ["habit_id": habit.id.uuidString]

            // Vide = tous les jours (un seul déclencheur) ; sinon un par jour prévu.
            let weekdays: [Int?] = habit.scheduledWeekdays.isEmpty ? [nil] : habit.scheduledWeekdays.map { $0 }
            for weekday in weekdays {
                var components = DateComponents()
                components.hour = hm.hour
                components.minute = hm.minute
                if let weekday { components.weekday = weekday }

                let suffix = weekday.map { "_\($0)" } ?? ""
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                center.add(UNNotificationRequest(identifier: "steady_habit_\(habit.id.uuidString)\(suffix)", content: content, trigger: trigger))
            }
            count += 1
        }
        return count
    }

    // MARK: - Check du soir (il reste des habitudes à valider)

    /// Rappel à 20h30, replanifié à chaque validation :
    /// - aujourd'hui, avec le compte exact restant — il disparaît dès que tout est validé ;
    /// - demain, en version générique (au cas où l'app ne serait pas ouverte de la journée).
    /// Jamais un jour de repos : la bienveillance d'abord.
    private func scheduleEveningCheck() {
        let cal = Calendar.current
        let now = Date()

        // Aujourd'hui : nombre précis d'habitudes prévues non validées.
        if !RestDayStore.contains(now) {
            let remaining = habits.filter { habit in
                guard habit.isScheduled(on: now) else { return false }
                let doneToday = habit.records.first { cal.isDate($0.date, inSameDayAs: now) }
                    .map { $0.count >= habit.dailyGoal } ?? false
                return !doneToday
            }.count

            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = 20; comps.minute = 30
            if remaining > 0, let fireDate = cal.date(from: comps), fireDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Steady"
                content.body = remaining == 1
                    ? L("Petit check du soir : il te reste 1 habitude à valider 🌿")
                    : L("Petit check du soir : il te reste \(remaining) habitudes à valider 🌿")
                content.sound = .default
                content.categoryIdentifier = "steady_evening_check"
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "steady_evening_check_today", content: content, trigger: trigger))
            }
        }

        // Demain : version générique, remplacée par la version précise dès que l'app s'ouvre.
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now) {
            var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
            comps.hour = 20; comps.minute = 30
            let content = UNMutableNotificationContent()
            content.title = "Steady"
            content.body = L("Petit check du soir : tes habitudes t'attendent 🌿")
            content.sound = .default
            content.categoryIdentifier = "steady_evening_check"
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "steady_evening_check_tomorrow", content: content, trigger: trigger))
        }
    }

    // MARK: - Rappel quotidien global (repli, guilt-free)

    private func scheduleGlobalDaily() {
        let content = UNMutableNotificationContent()
        content.title = "Steady"
        content.body = dailyReminderBody()
        content.sound = .default
        content.categoryIdentifier = "steady_daily_reminder"

        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
        center.add(UNNotificationRequest(identifier: "steady_free_daily", content: content, trigger: trigger))
    }

    // MARK: - Bilan hebdomadaire automatique (dimanche 19h, pour tous)

    private func scheduleWeeklyDigest() {
        var components = DateComponents()
        components.weekday = 1   // dimanche
        components.hour = 19
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = L("Ton bilan de la semaine")
        content.body = weeklySummaryBody()
        content.sound = .default
        content.categoryIdentifier = "steady_weekly_summary"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: "steady_weekly_digest", content: content, trigger: trigger))
    }

    // MARK: - Messages guilt-free

    /// Message du rappel quotidien : encourageant, varié, et conscient de la série en cours.
    private func dailyReminderBody() -> String {
        let streak = bestCurrentStreak()
        if streak >= 2 {
            return L("🔥 \(streak) jours d'affilée ! Continue à ton rythme, tu fais du beau travail.")
        }
        let messages = [
            L("Un petit moment pour toi aujourd'hui ? Tes habitudes t'attendent, sans pression."),
            L("Quel petit pas as-tu envie de faire aujourd'hui ?"),
            L("Pas à pas, c'est comme ça qu'on avance. À ton rythme."),
            L("Chaque petit pas compte. Prends un instant pour toi.")
        ]
        // Rotation stable selon le jour (pas d'aléatoire qui change à chaque reload).
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return messages[dayIndex % messages.count]
    }

    /// Meilleure série en cours parmi toutes les habitudes.
    private func bestCurrentStreak() -> Int {
        habits.map { currentStreak(for: $0) }.max() ?? 0
    }

    private func currentStreak(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let days = Set(habit.records.filter { $0.count >= habit.dailyGoal }.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: habit.creationDate)
        var streak = 0
        var day = today

        while day >= start {
            if habit.isScheduled(on: day) && !RestDayStore.contains(day) {
                if days.contains(day) {
                    streak += 1
                } else if day != today {
                    break
                }
            } else if days.contains(day) {
                streak += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
    
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    private func weeklyStreak(for habit: Habit) -> Int {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return habit.records.filter { $0.date >= weekAgo && $0.count >= habit.dailyGoal }.count
    }
    
    private func weeklySummaryBody() -> String {
        let total = habits.reduce(0) { $0 + weeklyStreak(for: $1) }
        if total == 0 {
            return L("Cette semaine était calme. Pas de souci, on reprend doucement lundi.")
        } else if total < 10 {
            return L("Belle semaine ! Tu as validé \(total) habitudes au total. Continue sur cette lancée.")
        } else {
            return L("Semaine exceptionnelle : \(total) validations. Tu progresses visiblement !")
        }
    }
}
