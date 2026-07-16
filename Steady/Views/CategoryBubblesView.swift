import SwiftUI

/// Vue d'ensemble des catégories en bulles : plus une catégorie contient
/// d'habitudes (et de priorités hautes), plus sa bulle est grosse.
/// Tap sur une bulle = filtrer la liste ; re-tap = tout afficher.
struct CategoryBubblesView: View {
    let habits: [Habit]
    @Binding var selected: HabitCategory?

    /// Poids d'une catégorie : 1 par habitude + bonus par priorité haute.
    private var weights: [(category: HabitCategory, weight: Int, count: Int)] {
        HabitCategory.allCases.compactMap { category in
            let members = habits.filter { $0.category == category }
            guard !members.isEmpty else { return nil }
            let weight = members.count + members.filter { $0.priority == .high }.count
            return (category, weight, members.count)
        }
        .sorted { $0.weight > $1.weight }
    }

    /// Diamètre : 56 pt minimum, +12 par point de poids, plafonné à 108.
    private func diameter(_ weight: Int) -> CGFloat {
        min(108, 56 + CGFloat(weight - 1) * 12)
    }

    var body: some View {
        // Une seule catégorie « Autre » = rien à regrouper, on n'affiche pas de bulles.
        if weights.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                    ForEach(weights, id: \.category) { entry in
                        bubble(entry)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: selected)
        }
    }

    private func bubble(_ entry: (category: HabitCategory, weight: Int, count: Int)) -> some View {
        let isSelected = selected == entry.category
        let size = diameter(entry.weight)
        return Button {
            HapticManager.lightImpact()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                selected = isSelected ? nil : entry.category
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: entry.category.icon)
                    .font(.system(size: size * 0.2, weight: .semibold))
                Text(entry.category.titleText)
                    .font(.system(size: max(11, size * 0.15), weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(entry.count)")
                    .font(.system(size: max(11, size * 0.13), weight: .semibold))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(width: size, height: size)
            .background(Circle().fill(entry.category.color.gradient))
            .overlay(
                Circle().strokeBorder(.white.opacity(isSelected ? 0.9 : 0), lineWidth: 3)
            )
            .shadow(color: entry.category.color.opacity(isSelected ? 0.5 : 0.25), radius: isSelected ? 10 : 5, y: 3)
            .scaleEffect(selected == nil || isSelected ? 1 : 0.85)
            .opacity(selected == nil || isSelected ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.category.titleText), \(entry.count) habitudes")
        .accessibilityHint(isSelected ? "Retirer le filtre" : "Filtrer sur cette catégorie")
    }
}
