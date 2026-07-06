import SwiftUI

/// Carte de motivation du jour (composant réutilisable).
struct MotivationCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Mot du coach")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.95))

            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Color.accentGradient)
        )
        .shadow(color: Color.brandAccent.opacity(0.3), radius: 14, y: 8)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MotivationCard(text: "Avance à ta vitesse. La constance bat l'intensité.")
        .padding()
        .background(Color.steadyBackground)
}
