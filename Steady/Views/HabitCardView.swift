import SwiftUI
import SwiftData

struct HabitCardView: View {
    let habit: Habit
    var store: HabitStore
    var onShowDetail: () -> Void = {}
    /// Demande de suppression (le parent affiche la confirmation).
    var onDelete: () -> Void = {}

    @State private var isPressed = false

    private var isCompleted: Bool {
        store.isCompleted(habit, on: Date())
    }

    private var streak: Int {
        store.currentStreak(for: habit)
    }

    private var dayCount: Int {
        store.dayCount(for: habit, on: Date())
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            iconBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isCompleted ? .white : .primary)

                HStack(spacing: 10) {
                    if habit.isCounter {
                        counterChip
                    }
                    if streak > 0 {
                        streakChip
                    }
                    if habit.category != .other {
                        categoryChip
                    }
                    if habit.priority == .high {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(isCompleted ? .white : .orange)
                            .accessibilityLabel("Priorité haute")
                    }
                }
            }

            Spacer(minLength: 8)

            checkIndicator
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .shadow(color: shadowColor, radius: 12, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onTapGesture { toggle() }
        .contextMenu {
            Button {
                onShowDetail()
            } label: {
                Label("Détails", systemImage: "chart.bar.doc.horizontal")
            }
            if habit.isCounter {
                Button {
                    store.addCount(habit, by: 0, reset: true)
                } label: {
                    Label("Remettre à zéro", systemImage: "arrow.counterclockwise")
                }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Supprimer l'habitude", systemImage: "trash")
            }
        }
        .opacity(store.isRestDay && !isCompleted ? 0.65 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCompleted)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(isCompleted ? "validée" : "non validée")\(streak > 0 ? ", série de \(streak) jours" : "")")
        .accessibilityHint(store.isRestDay ? "Jour de repos : rien n'est exigé, mais valider reste possible" : "Double-tapez pour valider cette habitude")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Sous-vues

    private var iconBadge: some View {
        Image(systemName: habit.icon)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(isCompleted ? Color.accentDeep : .white)
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(isCompleted ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.accentGradient))
            )
            .scaleEffect(isPressed ? 1.18 : 1.0)
            .symbolEffect(.bounce, value: isCompleted)
    }

    private var streakChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            Text("\(streak) j")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(isCompleted ? Color.white : Color.steadyFlame)
    }

    private var categoryChip: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isCompleted ? Color.white : habit.category.color)
                .frame(width: 7, height: 7)
            Text(habit.category.titleText)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isCompleted ? Color.white.opacity(0.9) : .secondary)
        .lineLimit(1)
    }

    private var counterChip: some View {
        Text("\(dayCount)/\(habit.dailyGoal)\(habit.unit.isEmpty ? "" : " \(habit.unit)")")
            .font(.caption.weight(.bold))
            .foregroundStyle(isCompleted ? Color.white : Color.accentDeep)
            .contentTransition(.numericText())
    }

    @ViewBuilder
    private var checkIndicator: some View {
        Group {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: isCompleted)
            } else if habit.isCounter {
                // Un tap = marquer comme fait directement (remise à zéro via l'appui long).
                Button {
                    store.addCount(habit, by: nil)
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Marquer « \(habit.name) » comme fait")
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            }
        }
        .scaleEffect(isPressed ? 1.2 : 1.0)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .fill(isCompleted ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadyCard))
    }

    private var shadowColor: Color {
        isCompleted ? Color.brandAccent.opacity(0.35) : Color.black.opacity(0.06)
    }

    // MARK: - Action

    private func toggle() {
        // Jour de repos : rien n'est exigé, mais valider reste permis (et ça compte).
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            store.toggleHabit(habit, on: Date())
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isPressed = false
            }
        }
    }

}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, DailyRecord.self, configurations: config)
    let habit = Habit(name: "Méditer", icon: "brain.head.profile")
    return HabitCardView(habit: habit, store: HabitStore())
        .modelContainer(container)
        .padding()
        .background(Color.steadyBackground)
}
