import Foundation
import Observation

/// Façade UNIQUE du droit Premium côté UI.
///
/// Analogie : Premium à vie = carte de membre gravée ; la récompense pub = badge
/// visiteur valable 24 h. Le vigile (ton gating) ne regarde qu'une chose :
/// « badge valide ? » — c'est `isPremium`.
///
/// La date d'essai vit dans `StoreManager` (une seule source de vérité, et tes
/// ~15 vues qui lisent `storeManager.isPremium` profitent de l'essai sans être
/// modifiées). Cette façade délègue, pour offrir une API claire à la nouvelle UI.
@MainActor
@Observable
final class EntitlementStore {
    private let storeManager: StoreManager

    init(storeManager: StoreManager) {
        self.storeManager = storeManager
    }

    /// Achat StoreKit réel (abonnement ou à vie).
    var hasLifetimePremium: Bool { storeManager.hasActivePurchase }

    /// Fin de l'essai débloqué par pub. `.distantPast` = aucun essai.
    var trialUntil: Date { storeManager.adTrialUntil }

    /// Le vigile : lu à chaque affichage → l'expiration est automatique
    /// (le temps fait le travail, aucun code de nettoyage nécessaire).
    var isPremium: Bool { storeManager.isPremium }

    /// L'essai actif vient-il de la pub ? (pour afficher « Premium jusqu'à 18h30 »)
    var isOnAdTrial: Bool { !hasLifetimePremium && trialUntil > .now }

    /// Accordé UNIQUEMENT par le callback de récompense AdMob.
    func grantRewardedPremium(hours: Int = 24) {
        storeManager.grantAdTrial(hours: hours)
    }
}
