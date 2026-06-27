import SwiftData
import SwiftUI

@Observable
final class HabitStore {
    private var context: ModelContext?
    let storeManager = StoreManager()
    
    var isRestDay: Bool {
        didSet {
            UserDefaults.standard.set(isRestDay, forKey: "steady_rest_day")
        }
    }
    
    init() {
        self.isRestDay = UserDefaults.standard.bool(forKey: "steady_rest_day")
        
        // Observer les changements de statut Premium pour rescheduler les notifications
        NotificationManager.shared.checkAuthorizationStatus()
    }
    
    func configure(with context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Règle métier Premium
    
    func canAddHabit(currentCount: Int) -> Bool {
        storeManager.isPremium || currentCount < 3
    }
    
    // MARK: - CRUD
    
    func addHabit(name: String, icon: String, colorHex: String = "#8DA399") throws {
        guard let context = context else { return }
        let habit = Habit(name: name, icon: icon, colorHex: colorHex)
        context.insert(habit)
        try context.save()
        
        // Met à jour les notifications Premium si actif
        refreshNotifications()
    }
    
    func toggleHabit(_ habit: Habit, on date: Date) {
        guard let context = context, !isRestDay else { return }
        
        let calendar = Calendar.current
        let todayRecord = habit.records.first { calendar.isDate($0.date, inSameDayAs: date) }
        
        if let record = todayRecord {
            if record.status == .completed {
                context.delete(record)
            } else {
                record.status = .completed
            }
        } else {
            let newRecord = DailyRecord(date: date, status: .completed, habit: habit)
            context.insert(newRecord)
        }
        
        try? context.save()
        HapticManager.lightImpact()
        
        // Vérifie si un streak est atteint pour notifier en Premium
        refreshNotifications()
    }
    
    func deleteHabit(_ habit: Habit) {
        guard let context = context else { return }
        context.delete(habit)
        try? context.save()
        refreshNotifications()
    }
    
    // MARK: - Notifications
    
    func refreshNotifications() {
        guard let context = context else { return }
        
        // Récupère les habitudes pour le NotificationManager
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.creationDate)])
        if let habits = try? context.fetch(descriptor) {
            NotificationManager.shared.updateHabits(habits)
            NotificationManager.shared.rescheduleAll(premium: storeManager.isPremium)
        }
    }
    
    // MARK: - Queries
    
    func isCompleted(_ habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current
        return habit.records.contains {
            calendar.isDate($0.date, inSameDayAs: date) && $0.status == .completed
        }
    }
    
    func weeklySummary(for habit: Habit) -> Int {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return habit.records.filter { $0.date >= weekAgo && $0.status == .completed }.count
    }
    
    func weeklyCompletionRate(for habit: Habit) -> Double {
        let count = weeklySummary(for: habit)
        return min(Double(count) / 7.0, 1.0)
    }

    // MARK: - Streaks & visualisations

    /// Nombre de jours consécutifs validés en remontant à partir d'aujourd'hui.
    /// Si aujourd'hui n'est pas (encore) validé, on part d'hier afin de ne pas
    /// « casser » un streak avant la fin de la journée.
    func currentStreak(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let completedDays = Set(
            habit.records
                .filter { $0.status == .completed }
                .map { calendar.startOfDay(for: $0.date) }
        )
        guard !completedDays.isEmpty else { return 0 }

        var streak = 0
        var day = calendar.startOfDay(for: Date())

        // Tolère le fait que « aujourd'hui » ne soit pas encore validé.
        if !completedDays.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }

        while completedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Les 7 derniers jours (du plus ancien au plus récent) avec leur état de validation.
    func last7Days(for habit: Habit) -> [(date: Date, completed: Bool)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let completedDays = Set(
            habit.records
                .filter { $0.status == .completed }
                .map { calendar.startOfDay(for: $0.date) }
        )

        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date: day, completed: completedDays.contains(day))
        }
    }

    /// Nombre d'habitudes validées aujourd'hui sur le total fourni.
    func completedTodayCount(among habits: [Habit]) -> Int {
        habits.filter { isCompleted($0, on: Date()) }.count
    }

    #if DEBUG
    /// Insère un jeu de données de démonstration (pour captures d'écran / aperçus).
    /// Déclenché uniquement par l'argument de lancement `-seedDemo` — jamais en production.
    func seedDemoData() {
        guard let context else { return }
        let demos: [(name: String, icon: String, offsets: [Int])] = [
            ("Méditer", "brain.head.profile", [0, 1, 2, 3, 4, 5, 6]),
            ("Lire 10 pages", "book.fill", [0, 1, 2, 4, 5, 6]),
            ("Boire de l'eau", "drop.fill", [0, 1, 2, 3, 6]),
            ("Courir", "figure.run", [1, 3, 5])
        ]
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for demo in demos {
            let habit = Habit(name: demo.name, icon: demo.icon)
            context.insert(habit)
            for offset in demo.offsets {
                if let day = cal.date(byAdding: .day, value: -offset, to: today) {
                    context.insert(DailyRecord(date: day, status: .completed, habit: habit))
                }
            }
        }
        try? context.save()
    }
    #endif
}

