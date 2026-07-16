import Foundation

struct WeeklyReview {
    let completed: Int
    let successRate: Int
    let bestHabit: String?
    let weakestHabit: String?
    let longestStreak: Int
    let averageStreak: Int
    let bestDay: String
    let worstDay: String
    let summary: String
}

struct MonthlyReport {
    let completionRate: Int
    let evolution: Int       // points de % vs mois précédent
    let totalCompleted: Int
    let newRecords: Int
    let missedHabits: Int
    let bestDay: String
    let averageCompletion: Int
    let summary: String
}

/// Génère les bilans hebdomadaire et mensuel, 100 % en local.
@MainActor
struct CoachReportEngine {
    private let cal = Calendar.current
    private let analytics = AnalyticsService()

    // MARK: - Hebdomadaire

    func weekly(habits: [Habit], store: HabitStore) -> WeeklyReview? {
        let active = habits.filter { !$0.records.isEmpty }
        guard !active.isEmpty else { return nil }

        let (done, scheduled) = window(active, store: store, days: 7)
        let weekRate = scheduled > 0 ? Int((Double(done) / Double(scheduled) * 100).rounded()) : 0

        let ranked = active.map { (h: $0, r: habitRate(of: $0, store: store, days: 7)) }.sorted { $0.r > $1.r }
        let streaks = active.map { store.currentStreak(for: $0) }
        let longest = active.map { store.longestStreak(for: $0) }.max() ?? 0
        let avg = streaks.isEmpty ? 0 : Int((Double(streaks.reduce(0, +)) / Double(streaks.count)).rounded())

        let bw = analytics.bestWorstWeekday(active)
        let bestDay = bw.map { analytics.weekdayName($0.best) } ?? "…"
        let worstDay = bw.map { analytics.weekdayName($0.worst) } ?? "…"

        let summary = weeklySummaryText(rate: weekRate, longest: longest, worstDay: worstDay, done: done)

        return WeeklyReview(
            completed: done, successRate: weekRate,
            bestHabit: ranked.first?.h.name, weakestHabit: ranked.count > 1 ? ranked.last?.h.name : nil,
            longestStreak: longest, averageStreak: avg,
            bestDay: bestDay, worstDay: worstDay, summary: summary
        )
    }

    private func weeklySummaryText(rate: Int, longest: Int, worstDay: String, done: Int) -> String {
        if done == 0 {
            return L("Semaine calme. Aucun jugement, on repart en douceur dès maintenant.")
        }
        if rate >= 80 {
            return L("Superbe semaine ! Tu as validé \(rate)% de tes habitudes et tenu une série de \(longest) jours. \(worstDay) reste ton jour à surveiller.")
        }
        if rate >= 50 {
            return L("Belle semaine : \(rate)% de réussite et une série de \(longest) jours. Vise un petit effort le \(worstDay).")
        }
        return L("Semaine en demi-teinte (\(rate)%). Choisis UNE habitude clé pour relancer la machine, sans pression.")
    }

    // MARK: - Mensuel

    func monthly(habits: [Habit], store: HabitStore) -> MonthlyReport? {
        let active = habits.filter { !$0.records.isEmpty }
        guard !active.isEmpty else { return nil }

        let thisRate = rateBetween(active, store: store, fromDaysAgo: 29, toDaysAgo: 0)
        let lastRate = rateBetween(active, store: store, fromDaysAgo: 59, toDaysAgo: 30)
        let evolution = thisRate - lastRate

        let total = active.reduce(0) { acc, h in
            acc + h.records.filter { $0.count >= h.dailyGoal && isWithin(days: 30, $0.date) }.count
        }
        let newRecords = active.filter { store.currentStreak(for: $0) >= store.longestStreak(for: $0) && store.currentStreak(for: $0) >= 3 }.count
        let missed = active.filter { h in
            !h.records.contains { $0.count >= h.dailyGoal && isWithin(days: 30, $0.date) }
        }.count
        let bw = analytics.bestWorstWeekday(active)
        let bestDay = bw.map { analytics.weekdayName($0.best) } ?? "…"

        let summary = monthlySummaryText(rate: thisRate, evolution: evolution, records: newRecords, total: total)

        return MonthlyReport(
            completionRate: thisRate, evolution: evolution, totalCompleted: total,
            newRecords: newRecords, missedHabits: missed, bestDay: bestDay,
            averageCompletion: thisRate, summary: summary
        )
    }

    private func monthlySummaryText(rate: Int, evolution: Int, records: Int, total: Int) -> String {
        var parts: [String] = []
        if evolution > 0 { parts.append(L("Tu progresses : +\(evolution) points vs le mois dernier.")) }
        else if evolution < 0 { parts.append(L("Léger recul (\(evolution) points), rien d'alarmant.")) }
        else { parts.append(L("Régularité stable ce mois-ci.")) }
        parts.append(L("\(total) validations au total, \(rate)% de réussite."))
        if records > 0 { parts.append(L("\(records) record(s) de série en cours. Bravo !")) }
        return parts.joined(separator: " ")
    }

    // MARK: - Helpers

    private func isWithin(days: Int, _ date: Date) -> Bool {
        guard let limit = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date())) else { return false }
        return date >= limit
    }

    /// (validées, prévues) sur les N derniers jours.
    private func window(_ habits: [Habit], store: HabitStore, days: Int) -> (Int, Int) {
        let today = cal.startOfDay(for: Date())
        var done = 0, scheduled = 0
        for h in habits {
            let completed = Set(h.records.filter { $0.count >= h.dailyGoal }.map { cal.startOfDay(for: $0.date) })
            for offset in 0..<days {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard day >= cal.startOfDay(for: h.creationDate), h.isScheduled(on: day) else { continue }
                scheduled += 1
                if completed.contains(day) { done += 1 }
            }
        }
        return (done, scheduled)
    }

    private func habitRate(of habit: Habit, store: HabitStore, days: Int) -> Double {
        let (d, s) = window([habit], store: store, days: days)
        return s > 0 ? Double(d) / Double(s) : 0
    }

    private func rateBetween(_ habits: [Habit], store: HabitStore, fromDaysAgo: Int, toDaysAgo: Int) -> Int {
        let today = cal.startOfDay(for: Date())
        var done = 0, scheduled = 0
        for h in habits {
            let completed = Set(h.records.filter { $0.count >= h.dailyGoal }.map { cal.startOfDay(for: $0.date) })
            for offset in toDaysAgo...fromDaysAgo {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard day >= cal.startOfDay(for: h.creationDate), h.isScheduled(on: day) else { continue }
                scheduled += 1
                if completed.contains(day) { done += 1 }
            }
        }
        return scheduled > 0 ? Int((Double(done) / Double(scheduled) * 100).rounded()) : 0
    }
}
