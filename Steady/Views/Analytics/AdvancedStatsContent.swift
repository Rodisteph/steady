import SwiftUI
import SwiftData
import Charts

/// Contenu des statistiques avancées (Premium).
/// Sans ScrollView ni barre de navigation : conçu pour être intégré dans l'écran « Progrès ».
struct AdvancedStatsContent: View {
    let habits: [Habit]
    var store: HabitStore

    private let analytics = AnalyticsService()

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            scoreCards
            dailyCard
            weeklyCard
            bestWorstCard
        }
    }

    // MARK: - Scores

    private var scoreCards: some View {
        let trend = analytics.trendScore(habits)
        let longestBest = habits.map { store.longestStreak(for: $0) }.max() ?? 0

        // 4 tuiles complémentaires du héros de la page Progrès (aucun doublon).
        // Wording humain : on dit ce que ça veut dire, pas le nom de la métrique.
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md), GridItem(.flexible())], spacing: Theme.Spacing.md) {
            StatTile(value: "\(analytics.completionRate(habits, days: 30))%", label: "Réussite sur 30 jours", icon: "checkmark.seal.fill", tint: .green)
            StatTile(value: "\(analytics.consistencyScore(habits))%", label: "Régularité", icon: "waveform.path.ecg", tint: .accentDeep)
            StatTile(value: L("\(longestBest) j"), label: "Record de série", icon: "trophy.fill", tint: .steadyFlame)
            trendTile(trend)
        }
    }

    /// Tuile de tendance lisible : « +3 · En hausse » plutôt qu'un « +0 » cryptique.
    private func trendTile(_ trend: Int) -> StatTile {
        if trend > 0 {
            return StatTile(value: "+\(trend)", label: "En hausse cette semaine", icon: "arrow.up.right.circle.fill", tint: .green)
        }
        if trend < 0 {
            return StatTile(value: "\(trend)", label: "Petit creux cette semaine", icon: "arrow.down.right.circle.fill", tint: .orange)
        }
        return StatTile(value: "=", label: "Stable cette semaine", icon: "equal.circle.fill", tint: .accentDeep)
    }

    // MARK: - Graphique quotidien

    private var dailyCard: some View {
        chartCard(title: "Validations (14 jours)") {
            Chart(analytics.dailyPoints(habits, days: 14)) { point in
                BarMark(
                    x: .value("Jour", point.date, unit: .day),
                    y: .value("Validées", point.done)
                )
                .foregroundStyle(Color.accentGradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) {
                    AxisValueLabel(format: .dateTime.day().month(.narrow))
                }
            }
            .frame(height: 150)
        }
    }

    // MARK: - Graphique hebdo

    private var weeklyCard: some View {
        chartCard(title: "Réussite hebdomadaire") {
            Chart(analytics.weeklyPoints(habits, weeks: 8)) { point in
                BarMark(
                    x: .value("Semaine", point.weekStart, unit: .weekOfYear),
                    y: .value("Réussite", Int((point.rate * 100).rounded()))
                )
                .foregroundStyle(Color.accentGradient)
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 150)
        }
    }

    // MARK: - Meilleur / pire jour

    @ViewBuilder
    private var bestWorstCard: some View {
        if let bw = analytics.bestWorstWeekday(habits) {
            HStack(spacing: Theme.Spacing.md) {
                StatTile(value: analytics.weekdayName(bw.best), label: "Ton jour star", icon: "star.fill", tint: .steadyFlame)
                StatTile(value: analytics.weekdayName(bw.worst), label: "Jour à dompter", icon: "figure.strengthtraining.traditional", tint: .orange)
            }
        }
    }

    // MARK: - Helpers

    private func chartCard<Content: View>(title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title).font(.headline)
            content()
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }
}
