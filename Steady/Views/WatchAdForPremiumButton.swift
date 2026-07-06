import SwiftUI

/// Opt-in explicite : cadeau additif (« débloque »), jamais culpabilisant.
/// Disparaît si Premium payé ; grisé si la pub n'est pas prête.
struct WatchAdForPremiumButton: View {
    var entitlements: EntitlementStore
    var ads: RewardedAdManager

    var body: some View {
        if !entitlements.isPremium {
            Button {
                ads.show { entitlements.grantRewardedPremium(hours: 24) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                    Text("Débloquer Premium pour aujourd'hui")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .disabled(!ads.isAdReady)                       // grisé si pas prête
            .task { await ads.loadAd() }                    // préchargement
            .accessibilityHint("Une courte vidéo débloque toutes les fonctions Premium pendant 24 heures.")
        } else if entitlements.isOnAdTrial {
            Label("Premium actif jusqu'à \(entitlements.trialUntil, format: .dateTime.hour().minute())",
                  systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentDeep)
        }
    }
}
