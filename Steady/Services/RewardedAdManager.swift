import GoogleMobileAds
import Observation
import UIKit

/// Gère UNE pub récompensée : préchargement, présentation, rechargement.
/// Isolé : ne connaît ni les habitudes, ni SwiftData, ni StoreKit.
///
/// Analogie : une boulangerie qui met le pain au four AVANT l'arrivée des
/// clients. `loadAd()` au lancement = pain chaud quand on clique.
@MainActor
@Observable
final class RewardedAdManager: NSObject, FullScreenContentDelegate {

    /// Une seule instance pour toute l'app (la pub préchargée est partagée,
    /// peu importe l'écran qui la présente).
    static let shared = RewardedAdManager()
    private override init() { super.init() }

    /// L'ID de prod vit ICI et nulle part ailleurs.
    ///
    /// En DEBUG on garde l'ID de TEST de Google : cliquer sur de vraies publicités
    /// pendant le développement est considéré comme du trafic invalide et peut
    /// faire suspendre le compte AdMob.
    private static var adUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/1712485313"   // ID de TEST Google officiel
        #else
        "ca-app-pub-3090498892331333/4364880280"   // bloc récompensé Steady (prod)
        #endif
    }

    private var rewardedAd: RewardedAd?
    private var onReward: (() -> Void)?

    /// Pilote l'état du bouton (grisé tant que false).
    var isAdReady: Bool { rewardedAd != nil }
    private(set) var isLoading = false

    /// Précharge. Échec = on note, on ne bloque jamais l'utilisateur.
    func loadAd() async {
        guard !isLoading, rewardedAd == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ad = try await RewardedAd.load(with: Self.adUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
        } catch {
            print("⚠️ Pub non chargée : \(error.localizedDescription)")  // fallback : bouton reste grisé
        }
    }

    /// Présente la pub. `onReward` ne part QUE si la vidéo est terminée.
    func show(onReward: @escaping () -> Void) {
        guard let ad = rewardedAd, let rootVC = UIApplication.rootViewController else { return }
        self.onReward = onReward
        rewardedAd = nil          // consommée : une pub = une présentation
        ad.present(from: rootVC) { [weak self] in
            // ⭐️ userDidEarnReward : le SEUL endroit qui accorde la récompense.
            self?.onReward?()
            self?.onReward = nil
        }
    }

    // MARK: - FullScreenContentDelegate

    /// Pub fermée (récompensée ou non) → on précharge la suivante.
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { await loadAd() }
    }

    /// Échec d'affichage → on nettoie et on recharge.
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        rewardedAd = nil
        onReward = nil
        Task { await loadAd() }
    }
}
