import Foundation

/// Un conseil quotidien du coach (généré 100 % localement).
struct CoachDailyInsight: Identifiable {
    let id = UUID()
    let icon: String
    /// Catégorie stable du conseil : sert à l'apprentissage et à l'anti-répétition.
    let tag: String
    /// Urgence : plus c'est haut, plus le conseil est prioritaire aujourd'hui.
    let priority: Int
    let text: String
}

/// Génère le « conseil du jour ». Il construit tous les conseils pertinents à
/// partir des données réelles, puis choisit **le plus utile aujourd'hui** :
/// urgence × ce que l'utilisateur a plébiscité (👍/👎) × fraîcheur (anti-répétition).
/// Le choix est figé pour la journée via [[CoachMemory]].
@MainActor
struct DailyInsightEngine {
    private let cal = Calendar.current
    private let analytics = AnalyticsService()

    func today(habits: [Habit], store: HabitStore) -> CoachDailyInsight? {
        let pool = candidates(habits: habits, store: store)
        guard !pool.isEmpty else { return nil }
        let memory = CoachMemory.shared

        // Déjà choisi aujourd'hui → on garde le même (stabilité sur la journée).
        if let tag = memory.todayTag(), let hit = pool.first(where: { $0.tag == tag }) {
            return hit
        }

        // Score = urgence × poids appris × fraîcheur. Un conseil vu il y a moins
        // de 3 jours est fortement dé-priorisé pour laisser tourner la variété.
        func score(_ i: CoachDailyInsight) -> Double {
            let freshness: Double = (memory.daysSinceShown(i.tag).map { $0 < 3 } ?? false) ? 0.2 : 1
            return Double(i.priority) * memory.weight(i.tag) * freshness
        }
        let best = pool.max { score($0) < score($1) } ?? pool[0]
        memory.setTodayTag(best.tag)
        return best
    }

    // MARK: - Génération des candidats

    func candidates(habits: [Habit], store: HabitStore) -> [CoachDailyInsight] {
        let active = habits.filter { !$0.records.isEmpty }
        guard !active.isEmpty else { return [] }
        var out: [CoachDailyInsight] = []
        func add(_ icon: String, _ tag: String, _ priority: Int, _ text: String) {
            out.append(CoachDailyInsight(icon: icon, tag: tag, priority: priority, text: text))
        }

        let today = cal.startOfDay(for: Date())

        // --- Aujourd'hui (le plus urgent : ce qui se joue MAINTENANT) -----
        let scheduledToday = active.filter { $0.isScheduled(on: today) }
        if !scheduledToday.isEmpty {
            let doneToday = scheduledToday.filter { store.isCompleted($0, on: today) }.count
            if doneToday == 0 {
                add("sunrise.fill", "today_zero", 100, L("Zéro validation pour l'instant. Première case cochée dans les 30 minutes, chiche ?"))
            } else if doneToday < scheduledToday.count {
                add("figure.walk", "today_partial", 90, L("\(doneToday)/\(scheduledToday.count) aujourd'hui. Tu ne vas pas t'arrêter si près du sans-faute ?"))
            }
        }

        // --- Séries -------------------------------------------------------
        let withStreak = active.map { (habit: $0, cur: store.currentStreak(for: $0), best: store.longestStreak(for: $0)) }
        if let top = withStreak.max(by: { $0.cur < $1.cur }), top.cur >= 2 {
            add("flame.fill", "streak_top", 60, L("« \(top.habit.name) » : \(top.cur) jours d'affilée. Continue ! 🔥"))
        }
        if let rec = withStreak.max(by: { $0.best < $1.best }), rec.best >= 3 {
            let remaining = max(1, rec.best - rec.cur + 1)
            if rec.cur >= 1 && rec.cur < rec.best {
                add("trophy.fill", "record_reach", 85, L("Plus que \(remaining) jour(s) pour battre ton record de \(rec.best) sur « \(rec.habit.name) ». Il tremble déjà."))
            }
            if rec.cur >= rec.best {
                add("crown.fill", "record_new", 80, L("Nouveau record sur « \(rec.habit.name) » : \(rec.cur) jours. Légendaire."))
            }
        }

        // --- Habitude faible : actionnable → prioritaire ----------------
        let ranked = active.map { (habit: $0, rate: habitRate($0)) }.sorted { $0.rate > $1.rate }
        if let weak = ranked.last, ranked.count > 1, weak.rate < 0.4 {
            add("lightbulb.fill", "habit_weak", 70, L("« \(weak.habit.name) » te résiste. Réduis-la à 2 minutes et gagne le bras de fer."))
        }
        if let strong = ranked.first, strong.rate >= 0.7 {
            add("star.fill", "habit_strong", 30, L("« \(strong.habit.name) » est ton habitude la plus solide."))
        }

        // --- Volume total : paliers (rare → à surfacer) -----------------
        let totalDone = active.reduce(0) { $0 + store.totalCompletions(for: $1) }
        for milestone in [50, 100, 250, 500, 1000] where totalDone >= milestone && totalDone < milestone + 30 {
            add("number.circle.fill", "milestone", 75, L("Tu as franchi \(milestone) validations au total. Quel chemin parcouru !"))
        }

        // --- Tendance ----------------------------------------------------
        let trend = analytics.trendScore(active)
        if trend > 0 { add("chart.line.uptrend.xyaxis", "trend_up", 45, L("Ta régularité progresse (+\(trend) cette semaine). Continue comme ça.")) }
        if trend < 0 { add("arrow.down.right", "trend_down", 65, L("Petit creux cette semaine. Pas de culpabilité, on repart en douceur.")) }

        // --- Jours de la semaine ----------------------------------------
        let weekdayStats = weekdayCompletion(active)
        if let best = weekdayStats.max(by: { $0.value < $1.value }), best.value >= 0.7 {
            add("calendar", "weekday_best", 35, L("Tu ne rates presque jamais le \(weekdayName(best.key)). Ton point fort."))
        }
        if let worst = weekdayStats.filter({ $0.value > 0 }).min(by: { $0.value < $1.value }), worst.value < 0.5 {
            add("calendar.badge.exclamationmark", "weekday_weak", 55, L("Le \(weekdayName(worst.key)) et toi, c'est compliqué. Cette semaine, prouve-lui qui commande."))
        }
        if let bw = analytics.bestWorstWeekday(active) {
            add("sun.max.fill", "day_best", 30, L("Ton jour le plus productif : \(analytics.weekdayName(bw.best))."))
            add("cloud.fill", "day_worst", 30, L("\(analytics.weekdayName(bw.worst)) demande un peu plus d'effort. Sois doux avec toi."))
        }

        // --- Moments de la journée --------------------------------------
        switch dominantTimeBucket(active) {
        case .morning: add("sunrise.fill", "time_bucket", 30, L("Tu valides souvent tôt le matin. Garde ce bel élan."))
        case .afternoon: add("sun.max.fill", "time_bucket", 30, L("L'après-midi est ton moment fort pour avancer."))
        case .evening: add("moon.stars.fill", "time_bucket", 30, L("Le soir te réussit bien. Les rappels du soir marchent pour toi."))
        case .none: break
        }

        // --- Réussite / régularité --------------------------------------
        let rate = analytics.completionRate(active, days: 30)
        if rate >= 80 { add("checkmark.seal.fill", "rate_high", 35, L("\(rate)% de réussite sur 30 jours. Tu es en pleine forme.")) }
        else if rate >= 50 { add("checkmark.circle.fill", "rate_mid", 30, L("\(rate)% de réussite ce mois-ci. Chaque pas compte.")) }
        let consistency = analytics.consistencyScore(active)
        if consistency >= 70 { add("waveform.path.ecg", "consistency", 30, L("Ta régularité est à \(consistency)%. Impressionnant.")) }

        // --- Week-end ----------------------------------------------------
        let weekendRate = weekendCompletion(active)
        if weekendRate < 0.4 { add("beach.umbrella.fill", "weekend_low", 50, L("Le week-end, tes habitudes partent en vacances sans toi. Rattrape-les.")) }
        else if weekendRate >= 0.7 { add("party.popper.fill", "weekend_high", 30, L("Même le week-end, tu gardes le cap. Bravo.")) }

        // --- Hier ---------------------------------------------------------
        if let yesterday = cal.date(byAdding: .day, value: -1, to: today) {
            let scheduledY = active.filter { $0.isScheduled(on: yesterday) }
            if !scheduledY.isEmpty, scheduledY.allSatisfy({ store.isCompleted($0, on: yesterday) }) {
                add("checkmark.circle.fill", "yesterday_win", 40, L("Hier, tout était validé. Belle journée !"))
            }
        }

        // --- Encouragements génériques (repli, chacun son tag pour tourner) -
        add("leaf.fill", "generic_1", 10, L("La constance bat l'intensité. Un petit pas aujourd'hui suffit."))
        add("heart.fill", "generic_2", 10, L("Sois fier de te montrer, même les jours sans envie."))
        add("sparkles", "generic_3", 10, L("Les petites actions répétées deviennent qui tu es."))
        add("hands.clap.fill", "generic_4", 10, L("Tu fais déjà mieux que le toi d'il y a un mois. Maintenant, vise celui du mois prochain."))
        add("eyes", "generic_5", 10, L("Ton futur toi observe. Offre-lui un spectacle correct."))
        add("timer", "generic_6", 10, L("Une habitude validée avant midi, c'est une journée qui commence en victoire. Chiche ?"))
        add("bolt.fill", "generic_7", 10, L("La discipline, c'est choisir entre ce que tu veux maintenant et ce que tu veux le plus."))

        return out
    }

    // MARK: - Analyses internes

    private enum TimeBucket { case morning, afternoon, evening, none }

    private func completionHours(_ habits: [Habit]) -> [Int] {
        habits.flatMap { h in
            h.records.filter { $0.count >= h.dailyGoal }.compactMap { r -> Int? in
                let c = cal.dateComponents([.hour, .minute], from: r.date)
                if c.hour == 0 && c.minute == 0 { return nil }
                return c.hour
            }
        }
    }

    private func dominantTimeBucket(_ habits: [Habit]) -> TimeBucket {
        let hours = completionHours(habits)
        guard hours.count >= 4 else { return .none }
        var m = 0, a = 0, e = 0
        for h in hours { switch h { case 5..<12: m += 1; case 12..<18: a += 1; default: e += 1 } }
        let best = max(m, a, e)
        guard Double(best) / Double(hours.count) >= 0.45 else { return .none }
        if best == m { return .morning }
        if best == a { return .afternoon }
        return .evening
    }

    /// Taux de complétion par jour de semaine (1=dim … 7=sam).
    private func weekdayCompletion(_ habits: [Habit]) -> [Int: Double] {
        var done = [Int: Int](), scheduled = [Int: Int]()
        let today = cal.startOfDay(for: Date())
        for h in habits {
            let completed = Set(h.records.filter { $0.count >= h.dailyGoal }.map { cal.startOfDay(for: $0.date) })
            for offset in 0..<90 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard day >= cal.startOfDay(for: h.creationDate), h.isScheduled(on: day) else { continue }
                let wd = cal.component(.weekday, from: day)
                scheduled[wd, default: 0] += 1
                if completed.contains(day) { done[wd, default: 0] += 1 }
            }
        }
        var rates: [Int: Double] = [:]
        for (wd, sched) in scheduled where sched >= 2 { rates[wd] = Double(done[wd] ?? 0) / Double(sched) }
        return rates
    }

    private func weekendCompletion(_ habits: [Habit]) -> Double {
        let stats = weekdayCompletion(habits)
        let weekend = [1, 7].compactMap { stats[$0] }   // dimanche + samedi
        guard !weekend.isEmpty else { return 1 }
        return weekend.reduce(0, +) / Double(weekend.count)
    }

    private func habitRate(_ habit: Habit) -> Double {
        let today = cal.startOfDay(for: Date())
        let completed = Set(habit.records.filter { $0.count >= habit.dailyGoal }.map { cal.startOfDay(for: $0.date) })
        var scheduled = 0, done = 0
        for offset in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            guard day >= cal.startOfDay(for: habit.creationDate), habit.isScheduled(on: day) else { continue }
            scheduled += 1
            if completed.contains(day) { done += 1 }
        }
        return scheduled > 0 ? Double(done) / Double(scheduled) : 1
    }

    private func weekdayName(_ weekday: Int) -> String {
        var c = Calendar(identifier: .gregorian)
        c.locale = LocalizationManager.shared.locale
        let symbols = c.standaloneWeekdaySymbols
        return symbols[(weekday - 1) % symbols.count].capitalized(with: LocalizationManager.shared.locale)
    }
}
