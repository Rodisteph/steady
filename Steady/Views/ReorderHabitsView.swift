import SwiftUI
import SwiftData

/// Écran dédié au glisser-déposer des habitudes (préserve le design de l'accueil).
struct ReorderHabitsView: View {
    @Query(sort: [SortDescriptor(\Habit.sortIndex), SortDescriptor(\Habit.creationDate)])
    private var habits: [Habit]

    let store: HabitStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { habit in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: habit.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.accentGradient))
                        Text(habit.name)
                            .font(.body.weight(.medium))
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    store.moveHabits(habits, from: source, to: destination)
                    HapticManager.lightImpact()
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Réorganiser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                        .bold()
                }
            }
        }
    }
}
