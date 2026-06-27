import SwiftUI
import SwiftData

struct WeeklySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.creationDate) private var habits: [Habit]

    var store: HabitStore

    private var totalCompleted: Int {
        habits.reduce(0) { $0 + store.weeklySummary(for: $1) }
    }

    private var bestStreak: Int {
        habits.map { store.currentStreak(for: $0) }.max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if habits.isEmpty {
                        ContentUnavailableView(
                            "Aucune donnée",
                            systemImage: "chart.bar",
                            description: Text("Ajoutez des habitudes pour voir vos statistiques.")
                        )
                        .padding(.top, 60)
                    } else {
                        statsHeader

                        ForEach(habits) { habit in
                            SummaryCard(habit: habit, store: store)
                        }

                        if totalCompleted > 0 {
                            Text("Super rythme ! Tu as validé \(totalCompleted) habitude\(totalCompleted > 1 ? "s" : "") cette semaine.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color.steadyBackground.ignoresSafeArea())
            .navigationTitle("Résumé")
        }
    }

    private var statsHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatTile(value: "\(totalCompleted)", label: "cette semaine", icon: "checkmark.circle.fill", tint: .steadySageDeep)
            StatTile(value: "\(bestStreak)", label: "meilleure série", icon: "flame.fill", tint: .steadyFlame)
        }
        .padding(.top, Theme.Spacing.sm)
    }
}

// MARK: - Tuile de statistique

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .steadyCard(cornerRadius: Theme.Radius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Carte de résumé d'une habitude

struct SummaryCard: View {
    let habit: Habit
    var store: HabitStore

    var body: some View {
        let count = store.weeklySummary(for: habit)
        let days = store.last7Days(for: habit)

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 10) {
                Image(systemName: habit.icon)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.steadySageGradient))
                Text(habit.name)
                    .font(.headline)
                Spacer()
                Text("\(count)/7")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.steadySageDeep)
            }

            WeekDotsRow(days: days)

            Text(weeklyMessage(name: habit.name, count: count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(count) validations sur 7 jours. \(weeklyMessage(name: habit.name, count: count))")
    }

    private func weeklyMessage(name: String, count: Int) -> String {
        switch count {
        case 0:
            return "Pas de validation cette semaine. Pas de souci, on reprend en douceur quand tu te sentiras prêt."
        case 1...2:
            return "Tu as validé \(count) fois cette semaine. Chaque petit pas compte !"
        case 3...5:
            return "Super rythme : \(count) validations cette semaine. Continue comme ça !"
        case 6:
            return "Excellent travail : \(count) validations. Tu es presque à la perfection !"
        default:
            return "Félicitations ! Validé tous les jours cette semaine. Sois fier de toi."
        }
    }
}

// MARK: - Rangée de points (7 derniers jours)

struct WeekDotsRow: View {
    let days: [(date: Date, completed: Bool)]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEEE" // initiale du jour
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.date) { day in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(day.completed ? AnyShapeStyle(Color.steadySageGradient) : AnyShapeStyle(Color.steadySurface))
                            .frame(width: 26, height: 26)
                        if day.completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    Text(Self.dayFormatter.string(from: day.date).uppercased())
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}
