import SwiftUI
import SwiftData

struct HabitCardView: View {
    let habit: Habit
    var store: HabitStore

    @State private var isPressed = false

    private var isCompleted: Bool {
        store.isCompleted(habit, on: Date())
    }

    private var streak: Int {
        store.currentStreak(for: habit)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            iconBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isCompleted ? .white : .primary)

                if streak > 0 {
                    streakChip
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
        .opacity(store.isRestDay ? 0.55 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCompleted)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(isCompleted ? "validée" : "non validée")\(streak > 0 ? ", série de \(streak) jours" : "")")
        .accessibilityHint(store.isRestDay ? "Jour de repos, validation non requise" : "Double-tapez pour valider cette habitude")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Sous-vues

    private var iconBadge: some View {
        Image(systemName: habit.icon)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(isCompleted ? Color.steadySageDeep : .white)
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(isCompleted ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.steadySageGradient))
            )
            .scaleEffect(isPressed ? 1.18 : 1.0)
    }

    private var streakChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            Text("\(streak) j")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(isCompleted ? Color.white : Color.steadyFlame)
    }

    private var checkIndicator: some View {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(isCompleted ? .white : Color.secondary.opacity(0.4))
            .scaleEffect(isPressed ? 1.2 : 1.0)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .fill(isCompleted ? AnyShapeStyle(Color.steadySageGradient) : AnyShapeStyle(Color.steadyCard))
    }

    private var shadowColor: Color {
        isCompleted ? Color.steadySage.opacity(0.35) : Color.black.opacity(0.06)
    }

    // MARK: - Action

    private func toggle() {
        guard !store.isRestDay else { return }

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
