import SwiftUI
import Observation

@MainActor
@Observable
final class CoachViewModel {
    private(set) var motivation: String = ""
    private(set) var insights: [Insight] = []
    private(set) var dailyInsight: CoachDailyInsight?
    private(set) var prediction: CoachPrediction?
    private(set) var suggestions: [CoachSuggestion] = []
    private(set) var weeklyReview: WeeklyReview?
    private(set) var monthlyReport: MonthlyReport?

    private let engine = AIRecommendationEngine()
    private let coach = AICoachService()
    private let insightEngine = DailyInsightEngine()
    private let predictionEngine = PredictionEngine()
    private let suggestionEngine = SmartSuggestionEngine()
    private let reportEngine = CoachReportEngine()

    /// Recalcule la motivation du jour et les conseils à partir des habitudes.
    func refresh(habits: [Habit], store: HabitStore) {
        let bestStreak = habits.map { store.currentStreak(for: $0) }.max() ?? 0
        motivation = coach.dailyMotivation(bestStreak: bestStreak)

        dailyInsight = insightEngine.today(habits: habits, store: store)
        prediction = predictionEngine.predict(habits: habits, store: store)
        suggestions = suggestionEngine.suggestions(habits: habits, store: store)
        weeklyReview = reportEngine.weekly(habits: habits, store: store)
        monthlyReport = reportEngine.monthly(habits: habits, store: store)

        var list = engine.insights(for: habits)

        // Conseil « série en cours » — on réutilise le calcul du store (DRY).
        if let best = habits.max(by: { store.currentStreak(for: $0) < store.currentStreak(for: $1) }) {
            let streak = store.currentStreak(for: best)
            if streak >= 3 {
                list.insert(
                    Insight(
                        kind: .streak,
                        title: "Belle série",
                        message: L("« \(best.name) » : \(streak) jours d'affilée. Continue ! 🔥")
                    ),
                    at: 0
                )
            }
        }

        insights = list
    }
}
