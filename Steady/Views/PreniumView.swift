import SwiftUI
import StoreKit

struct PremiumView: View {
    @Bindable var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    hero

                    VStack(spacing: Theme.Spacing.md) {
                        FeatureRow(icon: "infinity", title: "Habitudes illimitées", subtitle: "Suivez autant d'habitudes que vous voulez")
                        FeatureRow(icon: "bell.badge.fill", title: "Rappels par habitude", subtitle: "Une notification dédiée pour chacune")
                        FeatureRow(icon: "chart.bar.fill", title: "Statistiques avancées", subtitle: "Séries, résumés et tendances détaillées")
                        FeatureRow(icon: "heart.fill", title: "Soutien indépendant", subtitle: "Vous soutenez un développement solo")
                    }

                    purchaseSection
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color.steadyBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Fermer")
                }
            }
        }
    }

    // MARK: - Sous-vues

    private var hero: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.steadySageGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.steadySage.opacity(0.4), radius: 16, y: 8)
                Image(systemName: "crown.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white)
            }

            Text("Steady Premium")
                .font(.largeTitle.weight(.bold))

            Text("Débloquez tout le potentiel de vos habitudes")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.lg)
    }

    private var purchaseSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let product = storeManager.product {
                Text("Achat unique • \(product.displayPrice)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await storeManager.purchase() }
            } label: {
                Group {
                    if storeManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Débloquer Premium")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.steadySageGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .shadow(color: Color.steadySage.opacity(0.35), radius: 12, y: 6)
            }
            .disabled(storeManager.isLoading)

            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Text("Restaurer les achats")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .disabled(storeManager.isLoading)

            Link("Politique de confidentialité", destination: AppLinks.privacyPolicy)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            if let error = storeManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.steadySageDeep)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.steadySage.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard(cornerRadius: Theme.Radius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#Preview {
    PremiumView(storeManager: StoreManager())
}
