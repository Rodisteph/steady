import SwiftUI
import StoreKit

/// D'où le paywall est ouvert → adapte l'accroche (conversion contextuelle).
enum PremiumContext {
    case general, habitLimit, theme, stats, health, challenge, streak

    var headline: LocalizedStringKey {
        switch self {
        case .general:   return "Débloque tout le potentiel de tes habitudes"
        case .habitLimit: return "Suis toutes tes habitudes, sans limite"
        case .theme:     return "Rends l'app 100 % à ton image"
        case .stats:     return "Comprends enfin pourquoi tu décroches"
        case .health:    return "Laisse tes habitudes se valider toutes seules"
        case .challenge: return "Lance tous les défis que tu veux"
        case .streak:    return "Protège ta série, ne repars jamais de zéro"
        }
    }
}

struct PremiumView: View {
    @Bindable var storeManager: StoreManager
    /// Contexte d'ouverture (accroche adaptée). `.general` par défaut.
    var context: PremiumContext = .general
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
                        FeatureRow(icon: "heart.fill", title: "Tes habitudes se valident seules", subtitle: "Eau, méditation, distance, exercice via Apple Santé")
                        FeatureRow(icon: "paintpalette.fill", title: "Une app à ton image", subtitle: "Tous les thèmes de couleur premium")
                        FeatureRow(icon: "star.circle.fill", title: "Récompenses doublées", subtitle: "2× d'XP et de pièces, plus des avatars exclusifs")
                        FeatureRow(icon: "graduationcap.fill", title: "Mode Examens", subtitle: "Compte à rebours et sessions focus qui valident tes révisions")
                        FeatureRow(icon: "square.and.arrow.up.fill", title: "Ton Wrapped sans filigrane", subtitle: "Partage ton récap façon story, proprement")
                        FeatureRow(icon: "hand.raised.fill", title: "Zéro publicité", subtitle: "Jamais de pub, juste toi et tes habitudes")
                    }

                    comparison

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

    // MARK: - Comparatif Gratuit vs Premium
    //
    // L'argument de vente le plus direct : l'utilisateur voit d'un coup d'œil
    // ce qu'il rate. Placé juste avant les prix (moment de décision).

    /// (libellé, valeur gratuite, valeur premium). "✓"/"✗" → icône.
    private var comparisonRows: [(LocalizedStringKey, String, String)] {
        [
            ("Habitudes suivies",        "3",   "∞"),
            ("Défis en cours",           "1",   "∞"),
            ("Thèmes de couleur",        "1",   L("Tous")),
            ("Statistiques avancées",    "✗",   "✓"),
            ("Validation via Apple Santé", "✗", "✓"),
            ("Coach IA personnel",       "✗",   "✓"),
            ("Mode Examens et focus",    "✗",   "✓"),
            ("Wrapped sans filigrane",   "✗",   "✓"),
            ("Récompenses",              "×1",  "×2"),
            ("Publicités",               L("Oui"), L("Non")),
        ]
    }

    private var comparison: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Ce que tu débloques")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Gratuit")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: 58)
                Text("Premium")
                    .font(.caption2.weight(.bold)).foregroundStyle(Color.accentDeep)
                    .frame(width: 64)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Divider().opacity(0.5)

            ForEach(Array(comparisonRows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    Text(row.0)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    compareCell(row.1, premium: false)
                    compareCell(row.2, premium: true)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 9)
                .background(index.isMultiple(of: 2) ? Color.clear : Color.brandAccent.opacity(0.05))
            }
        }
        .steadyCard(cornerRadius: Theme.Radius.md)
    }

    @ViewBuilder private func compareCell(_ value: String, premium: Bool) -> some View {
        Group {
            switch value {
            case "✓":
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(premium ? Color.accentDeep : Color.secondary)
            case "✗":
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
            default:
                Text(value)
                    .font(premium ? .caption.weight(.bold) : .caption)
                    .foregroundStyle(premium ? Color.accentDeep : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: premium ? 64 : 58)
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
            Text(context.headline)   // accroche adaptée au déclencheur
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

    /// Équivalent mensuel de l'annuel (« 1,67 €/mois ») — l'argument qui parle
    /// à un budget étudiant, bien plus que le prix annuel brut.
    private var annualPerMonth: String? {
        guard let annual = storeManager.annual else { return nil }
        // On réutilise le format de StoreKit (et pas .currency(code:)) : sinon on
        // mélange le formatage de la locale de l'appareil (« 1,50 US$ ») avec celui
        // de la boutique (« $17.99 ») sur la même carte.
        return (annual.price / 12).formatted(annual.priceFormatStyle)
    }

    private var offers: some View {
        VStack(spacing: Theme.Spacing.md) {
            offerCard(
                offer: .annual,
                title: "Annuel",
                price: annualPerMonth.map { "\($0)/mois" } ?? storeManager.annual?.displayPrice,
                period: annualPerMonth != nil ? "soit \(storeManager.annual?.displayPrice ?? "")/an" : "par an",
                badge: "7 jours gratuits",
                footnote: "Le plus avantageux · -58 %"
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
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentDeep : .secondary)
                // Ligne 1 : titre + prix. Ligne 2 : badge/mention + période.
                // Le badge est sous le titre (et non à côté) : sinon titre, badge et
                // prix se disputent la largeur et « Annuel » se fait tronquer.
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                            .fixedSize()                 // le titre n'est jamais tronqué
                        Spacer(minLength: 4)
                        Text(price ?? "…")
                            .font(.headline)
                            .lineLimit(1)
                            .fixedSize()                 // le prix ne passe jamais sur 2 lignes
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)            // « 7 jours gratuits » sur UNE ligne
                                .fixedSize()
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentDeep))
                        }
                        Spacer(minLength: 4)
                        Text(period)
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    // La mention a sa propre ligne : à côté du badge et de la période
                    // elle se faisait tronquer (« Le plus avanta… »).
                    if let footnote {
                        Text(footnote)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
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

    /// Mentions légales de renouvellement selon l'offre choisie.
    private var termsText: String {
        switch selection {
        case .annual:
            return L("7 jours gratuits, puis \(storeManager.annual?.displayPrice ?? "")/an. Abonnement renouvelé automatiquement, annulable à tout moment.")
        case .monthly:
            return L("\(storeManager.monthly?.displayPrice ?? "")/mois. Abonnement renouvelé automatiquement, annulable à tout moment.")
        case .lifetime:
            return L("Paiement unique de \(storeManager.lifetime?.displayPrice ?? ""). Accès à vie, sans abonnement.")
        }
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

            // Conditions claires pour l'offre sélectionnée (exigence App Store 3.1.2).
            Text(termsText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

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
