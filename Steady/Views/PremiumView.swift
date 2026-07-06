import SwiftUI
import StoreKit

struct PremiumView: View {
    @Bindable var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    enum Offer { case annual, monthly, lifetime }
    @State private var selection: Offer = .annual

    private var selectedProduct: Product? {
        switch selection {
        case .annual: return storeManager.annual
        case .monthly: return storeManager.monthly
        case .lifetime: return storeManager.lifetime
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    hero

                    socialProof

                    VStack(spacing: Theme.Spacing.md) {
                        FeatureRow(icon: "bolt.fill", title: "Progresse deux fois plus vite", subtitle: "Suis toutes tes habitudes, sans aucune limite")
                        FeatureRow(icon: "magnifyingglass", title: "Comprends pourquoi tu décroches", subtitle: "Repère tes tendances et ton meilleur jour")
                        FeatureRow(icon: "sparkles", title: "Ton coach IA personnel", subtitle: "Des conseils sur mesure, chaque jour")
                        FeatureRow(icon: "heart.fill", title: "Tes habitudes se valident seules", subtitle: "Eau, méditation, pas — via Apple Santé")
                        FeatureRow(icon: "paintpalette.fill", title: "Une app à ton image", subtitle: "Tous les thèmes de couleur premium")
                    }

                    offers
                    purchaseSection
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Fermer")
                }
            }
        }
    }

    // MARK: - Preuve sociale
    //
    // ⚠️ À n'afficher honnêtement qu'une fois de vraies notes obtenues. Mets
    // `showRating`/`showCount` à false tant que l'app n'a pas ces chiffres réels
    // (Apple peut refuser des affirmations trompeuses).
    private let ratingValue = "4,9"
    /// ⚠️ N'activer qu'avec de VRAIES notes App Store (règle Apple 2.3 — pas d'affirmations trompeuses).
    private let showRating = false

    private var socialProof: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.steadyFlame)

            if showRating {
                Text("\(ratingValue) sur l'App Store")
                    .font(.subheadline.weight(.bold))
            }
            Text("Rejoins des milliers de personnes qui construisent de meilleures habitudes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle().fill(.white.opacity(0.18)).frame(width: 88, height: 88)
                Image(systemName: "crown.fill").font(.system(size: 40)).foregroundStyle(.white)
            }
            .padding(.bottom, 4)

            Text("Steady Premium")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text("Débloque tout le potentiel de tes habitudes")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Color.accentGradient))
        .shadow(color: Color.brandAccent.opacity(0.35), radius: 16, y: 8)
    }

    // MARK: - Offres

    private var offers: some View {
        VStack(spacing: Theme.Spacing.md) {
            offerCard(
                offer: .annual,
                title: "Annuel",
                price: storeManager.annual?.displayPrice,
                period: "par an",
                badge: "7 jours gratuits",
                footnote: "Le plus avantageux"
            )
            offerCard(
                offer: .monthly,
                title: "Mensuel",
                price: storeManager.monthly?.displayPrice,
                period: "par mois",
                badge: nil,
                footnote: nil
            )
            offerCard(
                offer: .lifetime,
                title: "À vie",
                price: storeManager.lifetime?.displayPrice,
                period: "paiement unique",
                badge: nil,
                footnote: "Sans abonnement"
            )
        }
    }

    private func offerCard(offer: Offer, title: LocalizedStringKey, price: String?, period: LocalizedStringKey, badge: LocalizedStringKey?, footnote: LocalizedStringKey?) -> some View {
        let selected = selection == offer
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = offer }
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentDeep : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentDeep))
                        }
                    }
                    if let footnote {
                        Text(footnote).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(price ?? "—").font(.headline)
                    Text(period).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Color.steadyCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(selected ? Color.accentDeep : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Achat

    private var purchaseSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {
                Task {
                    guard let product = selectedProduct else { return }
                    await storeManager.purchase(product)
                    if storeManager.isPremium { dismiss() }
                }
            } label: {
                Group {
                    if storeManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(selection == .annual ? "Commencer l'essai gratuit" : "Continuer")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .pulsingGlow()
            }
            .disabled(storeManager.isLoading || selectedProduct == nil)

            if selection == .annual {
                Text("7 jours gratuits, puis \(storeManager.annual?.displayPrice ?? "")/an. Annulable à tout moment.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await storeManager.restorePurchases()
                    if storeManager.isPremium { dismiss() }
                }
            } label: {
                Text("Restaurer les achats")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .disabled(storeManager.isLoading)

            // Essai 24 h contre une pub récompensée — opt-in, jamais bloquant.
            // Disparaît dès que isPremium == true → zéro pub pour les payeurs.
            WatchAdForPremiumButton(
                entitlements: EntitlementStore(storeManager: storeManager),
                ads: RewardedAdManager.shared
            )

            HStack(spacing: Theme.Spacing.md) {
                Link("Confidentialité", destination: AppLinks.privacyPolicy)
                Text("·").foregroundStyle(.secondary)
                Link("Conditions", destination: AppLinks.termsOfUse)
            }
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
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentDeep)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.brandAccent.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard(cornerRadius: Theme.Radius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

#Preview {
    PremiumView(storeManager: StoreManager())
}
