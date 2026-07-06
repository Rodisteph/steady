import SwiftData
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class HabitStore {
    private var context: ModelContext?
    let storeManager = StoreManager()
    
    var isRestDay: Bool {
        didSet {
            UserDefaults.standard.set(isRestDay, forKey: "steady_rest_day")
            if isRestDay {
                UserDefaults.standard.set(Date(), forKey: "steady_rest_day_date")
                RestDayStore.add(Date())      // journée protégée : ne cassera aucune série
            } else {
                RestDayStore.remove(Date())
            }
        }
    }

    init() {
        let stored = UserDefaults.standard.bool(forKey: "steady_rest_day")
        // Réinitialise automatiquement si le jour de repos date d'hier ou avant.
        if stored,
           let savedDate = UserDefaults.standard.object(forKey: "steady_rest_day_date") as? Date,
           !Calendar.current.isDateInToday(savedDate) {
            self.isRestDay = false
            UserDefaults.standard.set(false, forKey: "steady_rest_day")
        } else {
            self.isRestDay = stored
        }

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
        let count = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0
        let habit = Habit(name: name, icon: icon, colorHex: colorHex, sortIndex: count)
        context.insert(habit)
        try context.save()

        // Met à jour les notifications Premium si actif
        refreshNotifications()
    }

    /// Pré-charge les 3 habitudes d'un profil choisi à l'onboarding.
    func seedProfile(_ profile: HabitProfile) {
        guard let context = context else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0
        for (index, h) in profile.habits.enumerated() {
            context.insert(Habit(name: h.name, icon: h.icon, sortIndex: existing + index))
        }
        try? context.save()
        refreshNotifications()   // met aussi le widget à jour
    }

    /// Installe une routine du catalogue (crée toutes ses habitudes d'un coup).
    func installRoutine(_ specs: [RoutineTemplate.HabitSpec]) {
        guard let context = context else { return }
        var count = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0
        for spec in specs {
            let habit = Habit(name: spec.name, icon: spec.icon, sortIndex: count)
            habit.dailyGoal = max(1, spec.goal)
            habit.unit = spec.unit
            context.insert(habit)
            count += 1
        }
        try? context.save()
        refreshNotifications()   // met aussi le widget à jour
    }

    /// Réordonne les habitudes après un glisser-déposer et persiste les positions.
    func moveHabits(_ habits: [Habit], from source: IndexSet, to destination: Int) {
        guard let context = context else { return }
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in reordered.enumerated() {
            habit.sortIndex = index
        }
        try? context.save()
    }
    
    func toggleHabit(_ habit: Habit, on date: Date) {
        // Jour de repos : rien n'est exigé, mais valider reste permis (bienveillance ≠ interdiction).
        guard let context = context else { return }

        let wasCompleted = isCompleted(habit, on: date)
        let calendar = Calendar.current
        let record = habit.records.first { calendar.isDate($0.date, inSameDayAs: date) }

        if habit.isCounter {
            // Compteur : +1 ; une fois l'objectif atteint, un tap remet à zéro.
            if let record {
                if record.count >= habit.dailyGoal {
                    context.delete(record)
                } else {
                    record.count += 1
                }
            } else {
                context.insert(DailyRecord(date: date, status: .completed, count: 1, habit: habit))
            }
        } else {
            // Simple : oui / non.
            if let record {
                if record.status == .completed {
                    context.delete(record)
                } else {
                    record.status = .completed
                    record.count = 1
                }
            } else {
                context.insert(DailyRecord(date: date, status: .completed, count: 1, habit: habit))
            }
        }

        try? context.save()
        HapticManager.lightImpact()

        // Gamification : récompense quand l'habitude vient d'être complétée.
        if !wasCompleted && isCompleted(habit, on: date) {
            GamificationManager.shared.awardCompletion(streak: currentStreak(for: habit))
        }

        refreshNotifications()   // met aussi le widget à jour
    }

    /// Saisie rapide pour les habitudes chiffrées : ajoute d'un coup (+5, +10…),
    /// `amount: nil` = compléter directement, `reset` = remettre à zéro.
    func addCount(_ habit: Habit, by amount: Int?, on date: Date = Date(), reset: Bool = false) {
        guard let context = context, habit.isCounter else { return }
        let wasCompleted = isCompleted(habit, on: date)
        let calendar = Calendar.current
        let record = habit.records.first { calendar.isDate($0.date, inSameDayAs: date) }

        if reset {
            if let record { context.delete(record) }
        } else {
            let target = habit.dailyGoal
            let add = amount ?? target                       // nil = aller direct à l'objectif
            if let record {
                record.count = min(target, record.count + add)
                record.status = .completed
            } else {
                context.insert(DailyRecord(date: date, status: .completed, count: min(target, add), habit: habit))
            }
        }

        try? context.save()
        HapticManager.lightImpact()

        if !wasCompleted && isCompleted(habit, on: date) {
            GamificationManager.shared.awardCompletion(streak: currentStreak(for: habit))
            HapticManager.success()
        }

        refreshNotifications()   // widget + rappels (le message inclut la série à jour)
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

        updateWidget()
    }

    /// Écrit l'instantané pour le widget écran d'accueil et le recharge.
    func updateWidget() {
        guard let context = context else { return }
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.creationDate)]
        )
        guard let habits = try? context.fetch(descriptor) else { return }

        // Le widget montre les habitudes PRÉVUES aujourd'hui.
        let todays = habits.filter { $0.isScheduled(on: Date()) }
        let items = todays.prefix(6).map {
            SteadyWidgetSnapshot.Item(id: $0.id.uuidString, name: $0.name, icon: $0.icon, done: isCompleted($0, on: Date()))
        }
        let weeklyTotal = habits.reduce(0) { $0 + weeklySummary(for: $1) }
        let bestStreak = habits.map { currentStreak(for: $0) }.max() ?? 0
        let snapshot = SteadyWidgetSnapshot(
            completed: completedTodayCount(among: todays),
            total: todays.count,
            weeklyTotal: weeklyTotal,
            bestStreak: bestStreak,
            habits: Array(items)
        )
        SteadyWidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Applique les validations faites depuis le widget interactif (file d'attente App Group).
    func applyPendingWidgetToggles() {
        let pending = SteadyWidgetStore.pendingToggles()
        guard !pending.isEmpty, let context = context else { return }
        guard let habits = try? context.fetch(FetchDescriptor<Habit>()) else { return }
        for idString in pending {
            guard let uuid = UUID(uuidString: idString),
                  let habit = habits.first(where: { $0.id == uuid }) else { continue }
            toggleHabit(habit, on: Date())
        }
        SteadyWidgetStore.clearPending()
        updateWidget()
    }

    // MARK: - Queries
    
    func isCompleted(_ habit: Habit, on date: Date) -> Bool {
        dayCount(for: habit, on: date) >= habit.dailyGoal
    }

    /// Avancement du jour (nombre de validations pour une habitude chiffrée).
    func dayCount(for habit: Habit, on date: Date) -> Int {
        let calendar = Calendar.current
        return habit.records.first { calendar.isDate($0.date, inSameDayAs: date) }?.count ?? 0
    }
    
    func weeklySummary(for habit: Habit) -> Int {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return habit.records.filter { $0.date >= weekAgo && $0.count >= habit.dailyGoal }.count
    }

    /// Nombre de jours planifiés parmi les 7 derniers (vide = 7).
    func scheduledDaysLastWeek(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).filter { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return habit.isScheduled(on: day)
        }.count
    }
    
    // MARK: - Statistiques mensuelles

    /// Nombre de validations (toutes habitudes confondues) par jour du mois courant.
    func monthlyCompletionCounts(among habits: [Habit]) -> [Date: Int] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: Date()) else { return [:] }
        var counts: [Date: Int] = [:]
        for habit in habits {
            for record in habit.records where record.count >= habit.dailyGoal {
                if interval.contains(record.date) {
                    let day = cal.startOfDay(for: record.date)
                    counts[day, default: 0] += 1
                }
            }
        }
        return counts
    }

    /// Total de validations sur le mois courant.
    func monthlyTotal(among habits: [Habit]) -> Int {
        monthlyCompletionCounts(among: habits).values.reduce(0, +)
    }

    // MARK: - Détail d'une habitude

    /// Plus longue série jamais atteinte, en tenant compte du planning
    /// (les jours non prévus ne cassent pas la série).
    func longestStreak(for habit: Habit) -> Int {
        let cal = Calendar.current
        let days = Set(habit.records.filter { $0.count >= habit.dailyGoal }.map { cal.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        let today = cal.startOfDay(for: Date())
        var day = cal.startOfDay(for: habit.creationDate)
        var best = 0
        var current = 0

        while day <= today {
            if habit.isScheduled(on: day) && !RestDayStore.contains(day) {
                if days.contains(day) {
                    current += 1
                    best = max(best, current)
                } else if day != today {
                    current = 0
                }
            } else if days.contains(day) {
                // Validation un jour de repos / non prévu : ça compte quand même.
                current += 1
                best = max(best, current)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    /// Nombre total de validations dans tout l'historique.
    func totalCompletions(for habit: Habit) -> Int {
        habit.records.filter { $0.count >= habit.dailyGoal }.count
    }

    /// Modifie le nom et/ou l'icône d'une habitude.
    func updateHabit(_ habit: Habit, name: String, icon: String) {
        habit.name = name
        habit.icon = icon
        try? context?.save()
        refreshNotifications()
    }

    /// Heure la plus fréquente de validation (apprise de l'historique) — pour suggérer un rappel.
    func suggestedReminderHour(for habit: Habit) -> Int? {
        let calendar = Calendar.current
        let hours = habit.records
            .filter { $0.count >= habit.dailyGoal }
            .compactMap { record -> Int? in
                let comps = calendar.dateComponents([.hour, .minute], from: record.date)
                if comps.hour == 0 && comps.minute == 0 { return nil }   // rattrapage sans heure
                return comps.hour
            }
        guard hours.count >= 3 else { return nil }
        let counts = Dictionary(grouping: hours, by: { $0 }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }

    /// Active/désactive et règle l'heure du rappel d'une habitude.
    func setReminder(for habit: Habit, enabled: Bool, time: Date?) {
        habit.reminderEnabled = enabled
        habit.reminderTime = time
        try? context?.save()
        refreshNotifications()
    }

    /// Coche/décoche une habitude pour un jour précis (aujourd'hui ou passé).
    /// Permet le rattrapage rétroactif depuis le calendrier de détail.
    func toggleCompletion(_ habit: Habit, on date: Date) {
        guard let context = context else { return }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard day <= calendar.startOfDay(for: Date()) else { return }   // pas le futur

        if let record = habit.records.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            if record.count >= habit.dailyGoal {
                context.delete(record)                 // déjà atteint → on enlève
            } else {
                record.count = habit.dailyGoal          // rattrapage = objectif atteint
                record.status = .completed
            }
        } else {
            context.insert(DailyRecord(date: day, status: .completed, count: habit.dailyGoal, habit: habit))
        }
        try? context.save()
        HapticManager.lightImpact()
        refreshNotifications()   // met aussi le widget à jour
    }

    /// Règle l'objectif quotidien (1 = simple) et l'unité d'une habitude.
    func setGoal(for habit: Habit, goal: Int, unit: String) {
        habit.dailyGoal = max(1, goal)
        habit.unit = unit.trimmingCharacters(in: .whitespaces)
        try? context?.save()
        updateWidget()
    }

    // MARK: - Apple Santé

    /// Lie (ou délie) une habitude à une métrique Santé pour l'auto-validation.
    func setHealthMetric(for habit: Habit, metric: HealthMetric?) {
        habit.healthMetricRaw = metric?.rawValue ?? ""
        try? context?.save()
    }

    /// Valide automatiquement les habitudes liées à Santé si le seuil du jour est atteint.
    /// N'enlève jamais une validation manuelle (uniquement « auto-compléter »).
    func syncHealth() {
        guard let context = context else { return }
        guard let habits = try? context.fetch(FetchDescriptor<Habit>()) else { return }
        let today = Date()
        let linked = habits.filter { $0.healthMetric != nil && $0.isScheduled(on: today) }
        guard !linked.isEmpty else { return }

        Task { @MainActor in
            var changed = false
            for habit in linked {
                guard let metric = habit.healthMetric, !isCompleted(habit, on: today) else { continue }
                let value = await HealthManager.shared.todayValue(for: metric)
                if value >= metric.target(forGoal: habit.dailyGoal) {
                    markCompleteFromHealth(habit)
                    changed = true
                }
            }
            if changed { updateWidget() }
        }
    }

    private func markCompleteFromHealth(_ habit: Habit) {
        guard let context = context else { return }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        if let record = habit.records.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            record.count = max(record.count, habit.dailyGoal)
            record.status = .completed
        } else {
            context.insert(DailyRecord(date: day, status: .completed, count: habit.dailyGoal, habit: habit))
        }
        try? context.save()
    }

    /// Règle les jours prévus d'une habitude (vide = tous les jours).
    func setSchedule(for habit: Habit, weekdays: [Int]) {
        habit.scheduledWeekdays = weekdays.sorted()
        try? context?.save()
        refreshNotifications()   // met aussi le widget à jour
    }

    // MARK: - Réparation de série

    /// Coût en pièces pour protéger la journée d'hier.
    static let repairCost = 50

    /// Hier était un jour prévu, manqué, non protégé — et une série existait avant ?
    /// (= la série vient de casser et peut être réparée)
    func canRepairYesterday(for habit: Habit) -> Bool {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) else { return false }
        guard yesterday >= cal.startOfDay(for: habit.creationDate) else { return false }
        return habit.isScheduled(on: yesterday)
            && !RestDayStore.contains(yesterday)
            && !isCompleted(habit, on: yesterday)
            && streakBeforeYesterday(for: habit) > 0
    }

    /// La série telle qu'elle existait avant le trou d'hier (celle qu'on récupère en réparant).
    func streakBeforeYesterday(for habit: Habit) -> Int {
        let calendar = Calendar.current
        guard let anchor = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: Date())) else { return 0 }
        let completedDays = Set(
            habit.records
                .filter { $0.count >= habit.dailyGoal }
                .map { calendar.startOfDay(for: $0.date) }
        )
        guard !completedDays.isEmpty else { return 0 }

        let start = calendar.startOfDay(for: habit.creationDate)
        var streak = 0
        var day = anchor
        while day >= start {
            if habit.isScheduled(on: day) && !RestDayStore.contains(day) {
                if completedDays.contains(day) { streak += 1 } else { break }
            } else if completedDays.contains(day) {
                streak += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Protège la journée d'hier (jour de repos rétroactif, valable pour toutes les
    /// habitudes) : les séries repartent comme si hier n'avait pas compté.
    func repairYesterday() {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) else { return }
        RestDayStore.add(yesterday)
        HapticManager.success()
        refreshNotifications()   // widget + rappels reflètent la série retrouvée
    }

    // MARK: - Streaks & visualisations

    /// Nombre de jours consécutifs validés en remontant à partir d'aujourd'hui.
    /// Si aujourd'hui n'est pas (encore) validé, on part d'hier afin de ne pas
    /// « casser » un streak avant la fin de la journée.
    func currentStreak(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let completedDays = Set(
            habit.records
                .filter { $0.count >= habit.dailyGoal }
                .map { calendar.startOfDay(for: $0.date) }
        )
        guard !completedDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: habit.creationDate)
        var streak = 0
        var day = today

        while day >= start {
            // Un jour « bienveillance » est protégé : il ne casse jamais la série.
            if habit.isScheduled(on: day) && !RestDayStore.contains(day) {
                if completedDays.contains(day) {
                    streak += 1
                } else if day != today {
                    // Jour prévu non validé → la série s'arrête
                    // (mais on tolère « aujourd'hui » pas encore fait).
                    break
                }
            } else if completedDays.contains(day) {
                // Validé quand même un jour non prévu / de repos : ça compte.
                streak += 1
            }
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
                .filter { $0.count >= habit.dailyGoal }
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
        for (index, demo) in demos.enumerated() {
            let habit = Habit(name: demo.name, icon: demo.icon, sortIndex: index)
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

