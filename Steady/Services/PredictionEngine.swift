import Foundation

/// Niveau qualitatif (motivation, risque).
enum CoachLevel: String {
    case low, medium, high

    var label: String {
        switch self {
        case .low: return L("Faible")
        case .medium: return L("Moyen")
        case .high: return L("Élevé")
        }
    }
}

/// Prédictions du coach, calculées localement à partir de l'historique.
struct CoachPrediction {
    let todayChance: Int        // 0...100
    let motivation: CoachLevel  // motivation prévue pour demain
    let streakRisk: CoachLevel  // risque de casser une série aujourd'hui
}

@MainActor
struct PredictionEngine {
    private let cal = Calendar.current

    func predict(habits: [Habit], store: HabitStore) -> CoachPrediction? {
        let active = habits.filter { !$0.records.isEmpty }
        guard !active.isEmpty else { return nil }
        let today = cal.startOfDay(for: Date())
        let scheduled = active.filter { $0.isScheduled(on: today) }

        // --- Chance de complétion aujourd'hui ---------------------------
        // Mélange : taux historique du jour + progression déjà faite + heure.
        let weekdayRate = historicalRate(active, for: cal.component(.weekday, from: today))
        let doneToday = scheduled.filter { store.isCompleted($0, on: today) }.count
        let progress = scheduled.isEmpty ? 1 : Double(doneToday) / Double(scheduled.count)

        let hour = cal.component(.hour, from: Date())
        // Plus la journée avance sans tout valider, plus la chance baisse.
        let timePenalty = scheduled.isEmpty ? 0 : Double(max(0, hour - 9)) / 15.0 * (1 - progress) * 0.35

        var chance = (weekdayRate * 0.5 + progress * 0.5 - timePenalty)
        chance = min(1, max(0.05, chance))
        let todayChance = Int((chance * 100).rounded())

        // --- Motivation prévue pour demain ------------------------------
        let trend = AnalyticsService().trendScore(active)
        let bestStreak = active.map { store.currentStreak(for: $0) }.max() ?? 0
        let motivation: CoachLevel
        if bestStreak >= 5 || trend > 1 { motivation = .high }
        else if bestStreak >= 2 || trend >= 0 { motivation = .medium }
        else { motivation = .low }

        // --- Risque de casser une série aujourd'hui ---------------------
        let streaksAtRisk = scheduled.filter { store.currentStreak(for: $0) >= 2 && !store.isCompleted($0, on: today) }
        let streakRisk: CoachLevel
        if streaksAtRisk.isEmpty { streakRisk = .low }
        else if hour >= 20 { streakRisk = .high }
        else if hour >= 16 { streakRisk = .medium }
        else { streakRisk = .low }

        return CoachPrediction(todayChance: todayChance, motivation: motivation, streakRisk: streakRisk)
    }

    /// Taux de réussite historique pour un jour de semaine donné (90 derniers jours).
    private func historicalRate(_ habits: [Habit], for weekday: Int) -> Double {
        var scheduled = 0, done = 0
        let today = cal.startOfDay(for: Date())
        for h in habits {
            let completed = Set(h.records.filter { $0.count >= h.dailyGoal }.map { cal.startOfDay(for: $0.date) })
            for offset in 1...90 {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                guard day >= cal.startOfDay(for: h.creationDate), h.isScheduled(on: day) else { continue }
                guard cal.component(.weekday, from: day) == weekday else { continue }
                scheduled += 1
                if completed.contains(day) { done += 1 }
            }
        }
        return scheduled > 0 ? Double(done) / Double(scheduled) : 0.6
    }
}
