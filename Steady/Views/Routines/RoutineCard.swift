import SwiftUI

/// Carte d'une routine dans la liste (composant réutilisable).
struct RoutineCard: View {
    let routine: RoutineTemplate

    private var isAdvanced: Bool {
        if case .advanced = routine.level { return true }
        return false
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: routine.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(routine.category.color.gradient))

            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name).font(.headline)
                Text(routine.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    RoutineChip(text: routine.duration, icon: "clock", tint: .secondary)
                    RoutineChip(text: routine.level.label, icon: "chart.bar.fill", tint: routine.level.color)
                    if isAdvanced {
                        RoutineChip(text: "Premium", icon: "crown.fill", tint: .accentDeep)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .accessibilityElement(children: .combine)
    }
}

struct RoutineChip: View {
    let text: LocalizedStringKey
    let icon: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)   // « Advanced » + « Premium » tiennent sur une ligne
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
    }
}
