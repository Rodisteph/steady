import Foundation
import SwiftUI

/// Moteur d'analyse on-device : transforme l'historique des habitudes en conseils.
/// 100 % local, sans réseau — respecte la confidentialité de Steady.
struct AIRecommendationEngine {
    private let calendar = Calendar.current

    // MARK: - Point d'entrée

    func insights(for habits: [Habit]) -> [Insight] {
        let active = habits.filter { habit in habit.records.contains { $0.count >= habit.dailyGoal } }
        guard !active.isEmpty else { return [] }

        var result: [Insight] = []

        // 1) Meilleur moment de la journée
        if let (label, pct) = bestTimeOfDay(active), pct >= 50 {
            result.append(Insight(
                kind: .positive,
                title: "Ton meilleur moment",
                message: L("\(pct)% de tes validations ont lieu \(label).")
            ))
        }

        // 2) Régularité (30 derniers jours)
        let rate = overallCompletionRate(active)
        if rate > 0 {
            result.append(Insight(
                kind: .positive,
                title: "Régularité",
                message: L("Tu réussis \(rate)% de tes habitudes prévues sur les 30 derniers jours.")
            ))
        }

        // 3) Essoufflement
        if let avg = averageRunBeforeBreak(active), avg >= 2 {
            result.append(Insight(
                kind: .warning,
                title: "Attention à l'essoufflement",
                message: L("Tu t'arrêtes souvent après environ \(avg) jours. Anticipe ce cap, en douceur.")
            ))
        }

        // 4) Conseil ciblé sur l'habitude la plus difficile
        if let weak = weakestHabit(active) {
            if let hour = bestHour(for: weak) {
                result.append(Insight(
                    kind: .tip,
                    title: "Conseil",
                    message: L("« \(weak.name) » te résiste. Essaie de la déplacer vers \(hour)h, ton heure la plus efficace.")
                ))
            } else {
                result.append(Insight(
                    kind: .tip,
                    title: "Conseil",
                    message: L("« \(weak.name) » est la plus dure pour toi. Commence par une version mini, juste pour garder l'élan.")
                ))
            }
        }

        return result
    }

    // MARK: - Analyses

    /// Heures réelles de validation (on ignore les enregistrements « minuit pile »
    /// issus d'un rattrapage rétroactif, sans heure significative).
    private func completionHours(_ habits: [Habit]) -> [Int] {
        habits.flatMap { habit in
            habit.records
                .filter { $0.count >= habit.dailyGoal }
                .compactMap { record -> Int? in
                    let comps = calendar.dateComponents([.hour, .minute], from: record.date)
                    if comps.hour == 0 && comps.minute == 0 { return nil }
                    return comps.hour
                }
        }
    }

    private func bestTimeOfDay(_ habits: [Habit]) -> (label: String, percent: Int)? {
        let hours = completionHours(habits)
        guard hours.count >= 4 else { return nil }
        var morning = 0, afternoon = 0, evening = 0
        for h in hours {
            switch h {
            case 5..<12: morning += 1
            case 12..<18: afternoon += 1
            default: evening += 1
            }
        }
        let total = Double(hours.count)
        let buckets: [(String, Int)] = [
            (L("le matin"), morning),
            (L("l'après-midi"), afternoon),
            (L("le soir"), evening)
        ]
        guard let best = buckets.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        return (best.0, Int((Double(best.1) / total * 100).rounded()))
    }

    private func overallCompletionRate(_ habits: [Habit]) -> Int {
        let today = calendar.startOfDay(for: Date())
        var scheduled = 0, done = 0
        for habit in habits {
            let completed = Set(habit.records.filter { $0.count >= habit.dailyGoal }.map { calendar.startOfDay(for: $0.date) })
            for offset in 0..<30 {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard day >= calendar.startOfDay(for: habit.creationDate) else { continue }
                guard habit.isScheduled(on: day) else { continue }
                scheduled += 1
                if completed.contains(day) { done += 1 }
            }
        }
        guard scheduled > 0 else { return 0 }
        return Int((Double(done) / Double(scheduled) * 100).rounded())
    }

    /// Longueur moyenne des séries terminées par un abandon.
    private func averageRunBeforeBreak(_ habits: [Habit]) -> Int? {
        var runs: [Int] = []
        let today = calendar.startOfDay(for: Date())
        for habit in habits {
            let completed = Set(habit.records.filter { $0.count >= habit.dailyGoal }.map { calendar.startOfDay(for: $0.date) })
            guard !completed.isEmpty else { continue }
            var day = calendar.startOfDay(for: habit.creationDate)
            var current = 0
            while day <= today {
                if habit.isScheduled(on: day) {
                    if completed.contains(day) {
                        current += 1
                    } else if current > 0 {
                        runs.append(current)   // série terminée par un trou
                        current = 0
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        guard !runs.isEmpty else { return nil }
        return Int((Double(runs.reduce(0, +)) / Double(runs.count)).rounded())
    }

    private func weakestHabit(_ habits: [Habit]) -> Habit? {
        habits.min { habitRate($0) < habitRate($1) }
    }

    private func habitRate(_ habit: Habit) -> Double {
        let today = calendar.startOfDay(for: Date())
        let completed = Set(habit.records.filter { $0.count >= habit.dailyGoal }.map { calendar.startOfDay(for: $0.date) })
        var scheduled = 0, done = 0
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            guard day >= calendar.startOfDay(for: habit.creationDate), habit.isScheduled(on: day) else { continue }
            scheduled += 1
            if completed.contains(day) { done += 1 }
        }
        return scheduled > 0 ? Double(done) / Double(scheduled) : 1
    }

    private func bestHour(for habit: Habit) -> Int? {
        let hours = completionHours([habit])
        guard hours.count >= 3 else { return nil }
        let counts = Dictionary(grouping: hours, by: { $0 }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }
}
