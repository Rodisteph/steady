import Foundation

/// Calculs analytiques on-device pour le dashboard avancé.
/// Réutilise la sémantique « objectif atteint » + planning (DRY, cohérent avec le reste).
struct AnalyticsService {
    private let cal = Calendar.current

    struct DayPoint: Identifiable {
        let id = UUID()
        let date: Date
        let done: Int
        let scheduled: Int
        var rate: Double { scheduled > 0 ? Double(done) / Double(scheduled) : 0 }
    }

    struct WeekPoint: Identifiable {
        let id = UUID()
        let weekStart: Date
        let rate: Double
    }

    // MARK: - Brique de base

    private func dayStats(_ habits: [Habit], on day: Date) -> (scheduled: Int, done: Int) {
        let d = cal.startOfDay(for: day)
        var scheduled = 0, done = 0
        for habit in habits {
            guard d >= cal.startOfDay(for: habit.creationDate), habit.isScheduled(on: d) else { continue }
            scheduled += 1
            if habit.records.contains(where: { cal.isDate($0.date, inSameDayAs: d) && $0.count >= habit.dailyGoal }) {
                done += 1
            }
        }
        return (scheduled, done)
    }

    private func rate(_ habits: [Habit], fromOffset: Int, count: Int) -> Double {
        let today = cal.startOfDay(for: Date())
        var s = 0, d = 0
        for offset in fromOffset..<(fromOffset + count) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let st = dayStats(habits, on: day)
            s += st.scheduled; d += st.done
        }
        return s > 0 ? Double(d) / Double(s) : 0
    }

    // MARK: - Scores

    /// Taux de réussite (0–100) sur `days` jours.
    func completionRate(_ habits: [Habit], days: Int = 30) -> Int {
        Int((rate(habits, fromOffset: 0, count: days) * 100).rounded())
    }

    /// Régularité récente (14 jours).
    func consistencyScore(_ habits: [Habit]) -> Int {
        Int((rate(habits, fromOffset: 0, count: 14) * 100).rounded())
    }

    /// Tendance : différence (en points) entre les 7 derniers jours et les 7 précédents.
    func trendScore(_ habits: [Habit]) -> Int {
        let recent = rate(habits, fromOffset: 0, count: 7)
        let previous = rate(habits, fromOffset: 7, count: 7)
        return Int(((recent - previous) * 100).rounded())
    }

    // MARK: - Meilleur / pire jour de la semaine

    func bestWorstWeekday(_ habits: [Habit]) -> (best: Int, worst: Int)? {
        let today = cal.startOfDay(for: Date())
        var done = [Int: Int](), scheduled = [Int: Int]()
        for offset in 0..<90 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let wd = cal.component(.weekday, from: day)
            let st = dayStats(habits, on: day)
            scheduled[wd, default: 0] += st.scheduled
            done[wd, default: 0] += st.done
        }
        let rates = scheduled.compactMap { (wd, sched) -> (Int, Double)? in
            sched > 0 ? (wd, Double(done[wd] ?? 0) / Double(sched)) : nil
        }
        guard let best = rates.max(by: { $0.1 < $1.1 }), let worst = rates.min(by: { $0.1 < $1.1 }) else { return nil }
        return (best.0, worst.0)
    }

    // MARK: - Séries pour graphiques

    func dailyPoints(_ habits: [Habit], days: Int = 14) -> [DayPoint] {
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let st = dayStats(habits, on: day)
            return DayPoint(date: day, done: st.done, scheduled: st.scheduled)
        }
    }

    func weeklyPoints(_ habits: [Habit], weeks: Int = 8) -> [WeekPoint] {
        let today = Date()
        return (0..<weeks).reversed().compactMap { weekOffset in
            guard let ref = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: today),
                  let interval = cal.dateInterval(of: .weekOfYear, for: ref) else { return nil }
            var s = 0, d = 0
            var day = interval.start
            while day < interval.end && day <= cal.startOfDay(for: today) {
                let st = dayStats(habits, on: day)
                s += st.scheduled; d += st.done
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return WeekPoint(weekStart: interval.start, rate: s > 0 ? Double(d) / Double(s) : 0)
        }
    }

    /// Heatmap façon GitHub : intensité (0–1) par jour sur `days`.
    func contributions(_ habits: [Habit], days: Int = 98) -> [DayPoint] {
        let today = cal.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let st = dayStats(habits, on: day)
            return DayPoint(date: day, done: st.done, scheduled: st.scheduled)
        }
    }

    func weekdayName(_ weekday: Int) -> String {
        // Suit la langue choisie dans l'app (pas seulement celle du système).
        var localeCal = Calendar(identifier: .gregorian)
        localeCal.locale = LocalizationManager.shared.locale
        let symbols = localeCal.standaloneWeekdaySymbols   // index 0 = dimanche
        return symbols[(weekday - 1) % symbols.count].capitalized(with: LocalizationManager.shared.locale)
    }
}
