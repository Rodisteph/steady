import Foundation

/// Un conseil quotidien du coach (généré 100 % localement).
struct CoachDailyInsight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

/// Génère le « Daily Insight » : il construit tous les conseils pertinents à partir
/// des données réelles, puis en choisit un de façon stable sur la journée (rotation
/// quotidienne → jamais le même conseil deux jours de suite tant qu'il y a de la variété).
@MainActor
struct DailyInsightEngine {
    private let cal = Calendar.current
    private let analytics = AnalyticsService()

    func today(habits: [Habit], store: HabitStore) -> CoachDailyInsight? {
        let pool = candidates(habits: habits, store: store)
        guard !pool.isEmpty else { return nil }
        let day = cal.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return pool[day % pool.count]
    }

    // MARK: - Génération des candidats

    func candidates(habits: [Habit], store: HabitStore) -> [CoachDailyInsight] {
        let active = habits.filter { !$0.records.isEmpty }
        guard !active.isEmpty else { return [] }
        var out: [CoachDailyInsight] = []
        func add(_ icon: String, _ text: String) { out.append(CoachDailyInsight(icon: icon, text: text)) }

        let today = cal.startOfDay(for: Date())

        // --- Séries -------------------------------------------------------
        let withStreak = active.map { (habit: $0, cur: store.currentStreak(for: $0), best: store.longestStreak(for: $0)) }
        if let top = withStreak.max(by: { $0.cur < $1.cur }), top.cur >= 2 {
            add("flame.fill", L("« \(top.habit.name) » : \(top.cur) jours d'affilée. Continue ! 🔥"))
        }
        for s in withStreak where s.cur >= 3 {
            add("flame.fill", L("Tu enchaînes « \(s.habit.name) » depuis \(s.cur) jours. Solide."))
        }
        if let rec = withStreak.max(by: { $0.best < $1.best }), rec.best >= 3 {
            let remaining = max(1, rec.best - rec.cur + 1)
            if rec.cur >= 1 && rec.cur < rec.best {
                add("trophy.fill", L("Plus que \(remaining) jour(s) pour battre ton record de \(rec.best) sur « \(rec.habit.name) ». Il tremble déjà."))
            }
            if rec.cur >= rec.best {
                add("crown.fill", L("Nouveau record sur « \(rec.habit.name) » : \(rec.cur) jours. Légendaire."))
            }
        }

        // --- Jours de la semaine ----------------------------------------
        let weekdayStats = weekdayCompletion(active)
        if let best = weekdayStats.max(by: { $0.value < $1.value }), best.value >= 0.7 {
            add("calendar", L("Tu ne rates presque jamais le \(weekdayName(best.key)). Ton point fort."))
        }
        if let worst = weekdayStats.filter({ $0.value > 0 }).min(by: { $0.value < $1.value }), worst.value < 0.5 {
            add("calendar.badge.exclamationmark", L("Le \(weekdayName(worst.key)) et toi, c'est compliqué. Cette semaine, prouve-lui qui commande."))
        }
        // Jour le plus / moins productif
        if let bw = analytics.bestWorstWeekday(active) {
            add("sun.max.fill", L("Ton jour le plus productif : \(analytics.weekdayName(bw.best))."))
            add("cloud.fill", L("\(analytics.weekdayName(bw.worst)) demande un peu plus d'effort. Sois doux avec toi."))
        }

        // --- Moments de la journée --------------------------------------
        switch dominantTimeBucket(active) {
        case .morning: add("sunrise.fill", L("Tu valides souvent tôt le matin. Garde ce bel élan."))
        case .afternoon: add("sun.max.fill", L("L'après-midi est ton moment fort pour avancer."))
        case .evening: add("moon.stars.fill", L("Le soir te réussit bien. Les rappels du soir marchent pour toi."))
        case .none: break
        }

        // --- Régularité / tendance --------------------------------------
        let trend = analytics.trendScore(active)
        if trend > 0 { add("chart.line.uptrend.xyaxis", L("Ta régularité progresse (+\(trend) cette semaine). Continue comme ça.")) }
        if trend < 0 { add("arrow.down.right", L("Petit creux cette semaine. Pas de culpabilité — on repart en douceur.")) }
        let rate = analytics.completionRate(active, days: 30)
        if rate >= 80 { add("checkmark.seal.fill", L("\(rate)% de réussite sur 30 jours. Tu es en pleine forme.")) }
        else if rate >= 50 { add("checkmark.circle.fill", L("\(rate)% de réussite ce mois-ci. Chaque pas compte.")) }
        let consistency = analytics.consistencyScore(active)
        if consistency >= 70 { add("waveform.path.ecg", L("Ta régularité est à \(consistency)%. Impressionnant.")) }

        // --- Habitude forte / faible ------------------------------------
        let ranked = active.map { (habit: $0, rate: habitRate($0)) }.sorted { $0.rate > $1.rate }
        if let strong = ranked.first, strong.rate >= 0.7 {
            add("star.fill", L("« \(strong.habit.name) » est ton habitude la plus solide."))
        }
        if let weak = ranked.last, ranked.count > 1, weak.rate < 0.4 {
            add("lightbulb.fill", L("« \(weak.habit.name) » te résiste. Réduis-la à 2 minutes et gagne le bras de fer."))
        }

        // --- Week-end ----------------------------------------------------
        let weekendRate = weekendCompletion(active)
        if weekendRate < 0.4 { add("beach.umbrella.fill", L("Le week-end, tes habitudes partent en vacances sans toi. Rattrape-les.")) }
        else if weekendRate >= 0.7 { add("party.popper.fill", L("Même le week-end, tu gardes le cap. Bravo.")) }

        // --- Hier / aujourd'hui -----------------------------------------
        if let yesterday = cal.date(byAdding: .day, value: -1, to: today) {
            let scheduledY = active.filter { $0.isScheduled(on: yesterday) }
            if !scheduledY.isEmpty, scheduledY.allSatisfy({ store.isCompleted($0, on: yesterday) }) {
                add("checkmark.circle.fill", L("Hier, tout était validé. Belle journée !"))
            }
        }
        let scheduledToday = active.filter { $0.isScheduled(on: today) }
        if !scheduledToday.isEmpty {
            let doneToday = scheduledToday.filter { store.isCompleted($0, on: today) }.count
            if doneToday == 0 { add("sunrise.fill", L("Zéro validation pour l'instant. Première case cochée dans les 30 minutes — chiche ?")) }
            else if doneToday < scheduledToday.count { add("figure.walk", L("\(doneToday)/\(scheduledToday.count) aujourd'hui. Tu ne vas pas t'arrêter si près du sans-faute ?")) }
        }

        // --- Volume total ------------------------------------------------
        let totalDone = active.reduce(0) { $0 + store.totalCompletions(for: $1) }
        for milestone in [50, 100, 250, 500, 1000] where totalDone >= milestone && totalDone < milestone + 30 {
            add("number.circle.fill", L("Tu as franchi \(milestone) validations au total. Quel chemin parcouru !"))
        }

        // --- Encouragements génériques (toujours dispo) -----------------
        // Mélange assumé : douceur, humour et petits défis.
        add("leaf.fill", L("La constance bat l'intensité. Un petit pas aujourd'hui suffit."))
        add("heart.fill", L("Sois fier de te montrer, même les jours sans envie."))
        add("sparkles", L("Les petites actions répétées deviennent qui tu es."))
        add("hands.clap.fill", L("Tu fais déjà mieux que le toi d'il y a un mois. Maintenant, vise celui du mois prochain."))
        add("eyes", L("Ton futur toi observe. Offre-lui un spectacle correct."))
        add("timer", L("Une habitude validée avant midi, c'est une journée qui commence en victoire. Chiche ?"))
        add("bolt.fill", L("La discipline, c'est choisir entre ce que tu veux maintenant et ce que tu veux le plus."))

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
