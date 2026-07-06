import SwiftUI

/// Carte d'un conseil/insight (composant réutilisable).
struct InsightCard: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: insight.kind.icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(insight.kind.tint))

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(insight.title) + Text(". ") + Text(insight.message))
    }
}
