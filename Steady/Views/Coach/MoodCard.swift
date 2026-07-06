import SwiftUI
import SwiftData

/// Suivi d'humeur : ludique (réaction du coach, animations) et utile
/// (semaine d'humeurs visible + corrélation avec les habitudes).
struct MoodCard: View {
    var habits: [Habit]
    var store: HabitStore

    @Environment(\.modelContext) private var context
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]
    @State private var reactionVisible = false

    private var todayMood: MoodEntry? {
        moods.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Comment te sens-tu ?", systemImage: "face.smiling")
                .font(.headline)

            // Sélecteur du jour
            HStack {
                ForEach(Mood.allCases) { mood in
                    let selected = todayMood?.value == mood.rawValue
                    Button {
                        select(mood)
                    } label: {
                        Text(mood.emoji)
                            .font(.system(size: 34))
                            .padding(10)
                            .background(Circle().fill(selected ? Color.brandAccent.opacity(0.25) : Color.clear))
                            .scaleEffect(selected ? 1.15 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(["Triste", "Neutre", "Heureux"][mood.rawValue])
                    if mood != .happy { Spacer() }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: todayMood?.value)

            // Réaction du coach (apparition douce après le choix)
            if let mood = todayMood.flatMap({ Mood(rawValue: $0.value) }) {
                Text(reaction(for: mood))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentDeep)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(reactionVisible ? 1 : 0)
                    .offset(y: reactionVisible ? 0 : 6)
                    .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { reactionVisible = true } }
            }

            // Ta semaine en émotions
            weekStrip

            if let correlation {
                Text(correlation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }

    // MARK: - Semaine d'humeurs

    private var weekStrip: some View {
        let cal = Calendar.current
        let days: [(Date, Int?)] = (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let mood = moods.first { cal.isDate($0.date, inSameDayAs: day) }?.value
            return (day, mood)
        }
        var formatter: DateFormatter {
            let f = DateFormatter()
            f.locale = LocalizationManager.shared.locale
            f.dateFormat = "EEEEE"
            return f
        }
        return HStack(spacing: 0) {
            ForEach(days, id: \.0) { day, value in
                VStack(spacing: 4) {
                    if let value, let mood = Mood(rawValue: value) {
                        Text(mood.emoji).font(.footnote)
                    } else {
                        Circle().fill(Color.secondary.opacity(0.2)).frame(width: 7, height: 7).padding(.vertical, 4)
                    }
                    Text(formatter.string(from: day).uppercased())
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(cal.isDateInToday(day) ? Color.accentDeep : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 2)
        .accessibilityHidden(true)
    }

    // MARK: - Actions & textes

    private func select(_ mood: Mood) {
        HapticManager.lightImpact()
        reactionVisible = false
        if let entry = todayMood {
            entry.value = mood.rawValue
        } else {
            context.insert(MoodEntry(date: Date(), value: mood.rawValue))
        }
        try? context.save()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) { reactionVisible = true }
    }

    /// Petite réaction du coach, adaptée à l'humeur (varie selon le jour).
    private func reaction(for mood: Mood) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        switch mood {
        case .happy:
            let pool = [
                L("Belle énergie ! Profites-en pour valider une habitude de plus 💪"),
                L("Ça fait plaisir à voir. Garde cette lancée !"),
                L("Super ! Les bons jours construisent les bonnes semaines.")
            ]
            return pool[day % pool.count]
        case .neutral:
            let pool = [
                L("Journée normale, et c'est très bien. Un petit pas suffit."),
                L("Pas besoin d'être au top pour avancer un peu."),
                L("Stable, c'est déjà solide. Une petite victoire pour pimenter ?")
            ]
            return pool[day % pool.count]
        case .sad:
            let pool = [
                L("Merci de l'avoir noté. Sois doux avec toi aujourd'hui 💚"),
                L("Les jours difficiles passent. Le jour de repos est là pour ça."),
                L("Prends soin de toi d'abord. Tes habitudes t'attendront.")
            ]
            return pool[day % pool.count]
        }
    }

    /// Corrélation simple : humeur moyenne les jours « actifs » vs « inactifs ».
    private var correlation: String? {
        guard moods.count >= 5 else { return nil }
        let cal = Calendar.current
        var active: [Int] = [], idle: [Int] = []
        for m in moods {
            let day = cal.startOfDay(for: m.date)
            let didSomething = habits.contains { store.isCompleted($0, on: day) }
            if didSomething { active.append(m.value) } else { idle.append(m.value) }
        }
        guard !active.isEmpty, !idle.isEmpty else { return nil }
        let avgActive = Double(active.reduce(0, +)) / Double(active.count)
        let avgIdle = Double(idle.reduce(0, +)) / Double(idle.count)
        if avgActive - avgIdle >= 0.4 {
            return L("Tu te sens nettement mieux les jours où tu valides tes habitudes. 💚")
        }
        if avgIdle - avgActive >= 0.4 {
            return L("Ton humeur ne dépend pas que des habitudes — prends soin de toi avant tout.")
        }
        return L("Continue à noter ton humeur : des tendances vont apparaître.")
    }
}
