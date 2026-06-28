import SwiftUI
import SwiftData

// MARK: - Données de la carte de partage
//
// Un « sac » de valeurs simples (String, Int, Bool) calculé depuis le
// HabitStore. La carte ne dépend ainsi PAS de SwiftData au moment du rendu
// image — c'est ce qui rend l'export en image fiable et rapide.

struct WeeklyShareStats {
    let totalCompleted: Int      // validations sur les 7 derniers jours
    let bestStreak: Int          // meilleure série en cours
    let weekPercent: Int         // régularité moyenne 0...100
    let dateRange: String        // ex. « 23 – 29 juin »
    let habits: [HabitLine]      // jusqu'à 3 habitudes mises en avant
    let extraHabits: Int         // nombre d'habitudes non affichées

    struct HabitLine: Identifiable {
        let id: UUID
        let name: String
        let icon: String
        let days: [Bool]         // 7 jours, du plus ancien au plus récent
    }

    /// Construit les stats à partir des habitudes et du store existant.
    static func make(from habits: [Habit], store: HabitStore) -> WeeklyShareStats {
        let total = habits.reduce(0) { $0 + store.weeklySummary(for: $1) }
        let best = habits.map { store.currentStreak(for: $0) }.max() ?? 0
        let percent = habits.isEmpty
            ? 0
            : Int((Double(total) / Double(habits.count * 7) * 100).rounded())

        let shown = habits.prefix(3).map { habit in
            HabitLine(
                id: habit.id,
                name: habit.name,
                icon: habit.icon,
                days: store.last7Days(for: habit).map { $0.completed }
            )
        }

        // Plage de dates des 7 derniers jours, localisée automatiquement.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let range = "\(start.formatted(.dateTime.day().month(.abbreviated))) – \(today.formatted(.dateTime.day().month(.abbreviated)))"

        return WeeklyShareStats(
            totalCompleted: total,
            bestStreak: best,
            weekPercent: percent,
            dateRange: range,
            habits: Array(shown),
            extraHabits: max(0, habits.count - shown.count)
        )
    }
}

// MARK: - Carte visuelle exportable
//
// Vue à taille fixe (360 × 450 pt) pensée pour être transformée en image.
// Couleurs volontairement NON adaptatives (dégradé sauge + blanc) pour que
// l'image rendue soit identique en mode clair comme en mode sombre.

struct ShareCardView: View {
    let stats: WeeklyShareStats

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            hero
            tiles
            habitList
            Spacer(minLength: 0)
            footer
        }
        .padding(26)
        .frame(width: 360, height: 450)
        .foregroundStyle(.white)
        .background(Color.steadySageGradient)
    }

    // En-tête : marque + plage de dates
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20, weight: .bold))
                Text("Steady")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            Spacer()
            Text(stats.dateRange)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .opacity(0.85)
        }
    }

    // Chiffre vedette : régularité de la semaine
    private var hero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Ma semaine")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .opacity(0.85)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(stats.weekPercent)")
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                Text("%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .opacity(0.9)
            }
            Text("de régularité, à mon rythme")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .opacity(0.85)
        }
    }

    // Deux tuiles : validations + meilleure série
    private var tiles: some View {
        HStack(spacing: 12) {
            tile(icon: "checkmark.circle.fill", value: "\(stats.totalCompleted)", label: "validations")
            tile(icon: "flame.fill", value: "\(stats.bestStreak)", label: "meilleure série")
        }
    }

    private func tile(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.18)))
    }

    // Liste d'habitudes avec leurs 7 points (du plus ancien au plus récent)
    private var habitList: some View {
        VStack(spacing: 8) {
            ForEach(stats.habits) { line in
                HStack(spacing: 10) {
                    Image(systemName: line.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white.opacity(0.22)))
                    Text(line.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    HStack(spacing: 5) {
                        ForEach(Array(line.days.enumerated()), id: \.offset) { _, done in
                            Circle()
                                .fill(.white.opacity(done ? 1.0 : 0.3))
                                .frame(width: 9, height: 9)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
            }

            if stats.extraHabits > 0 {
                Text("+ \(stats.extraHabits) autre\(stats.extraHabits > 1 ? "s" : "")")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .opacity(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
    }

    private var footer: some View {
        Text("Suivi d'habitudes sans culpabilité")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .opacity(0.8)
    }
}

#Preview {
    ShareCardView(
        stats: WeeklyShareStats(
            totalCompleted: 18,
            bestStreak: 6,
            weekPercent: 64,
            dateRange: "23 – 29 juin",
            habits: [
                .init(id: UUID(), name: "Méditer", icon: "brain.head.profile", days: [true, true, false, true, true, true, false]),
                .init(id: UUID(), name: "Lire 10 pages", icon: "book.fill", days: [true, false, true, true, false, true, true]),
                .init(id: UUID(), name: "Boire de l'eau", icon: "drop.fill", days: [true, true, true, false, false, true, true])
            ],
            extraHabits: 1
        )
    )
    .padding()
    .background(Color.steadyBackground)
}
