import SwiftUI

/// La « marketplace » de routines : filtre par catégorie + liste installable.
struct RoutineCategoryView: View {
    var store: HabitStore
    /// Appelé après installation (le parent ferme la feuille).
    var onInstalled: () -> Void

    @State private var routineStore = RoutineStore()
    @State private var selected: RoutineCategory?
    @Environment(\.dismiss) private var dismiss

    private var filtered: [RoutineTemplate] {
        guard let selected else { return routineStore.routines }
        return routineStore.routines(in: selected)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    categoryBar
                    ForEach(filtered) { routine in
                        NavigationLink {
                            RoutineDetailView(routine: routine, store: store) {
                                onInstalled()
                            }
                        } label: {
                            RoutineCard(routine: routine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                categoryChip(nil, title: "Toutes", icon: "square.grid.2x2.fill", color: .accentDeep)
                ForEach(routineStore.categories) { category in
                    categoryChip(category, title: category.title, icon: category.icon, color: category.color)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categoryChip(_ category: RoutineCategory?, title: LocalizedStringKey, icon: String, color: Color) -> some View {
        let isOn = selected == category
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = category }
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isOn ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isOn ? AnyShapeStyle(color) : AnyShapeStyle(Color.steadyCard))
            )
        }
        .buttonStyle(.plain)
    }
}
