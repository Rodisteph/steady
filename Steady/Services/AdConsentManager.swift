import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency
import UIKit

/// Consentement RGPD (UMP), PUIS autorisation de suivi (ATT), PUIS démarrage du
/// SDK AdMob. Cet ordre est celui recommandé par Google : le formulaire UMP
/// explique le contexte, le prompt ATT d'Apple arrive ensuite, et le SDK ne
/// démarre qu'une fois les deux réponses connues.
///
/// Sans consentement aux pubs personnalisées, Google sert automatiquement des
/// pubs limitées/non personnalisées : ça marche, ça paie juste moins.
///
/// ⚠️ À appeler quand l'UI est à l'écran (le formulaire a besoin d'un
/// ViewController) — d'où le `.task` sur RootView et non `SteadyApp.init()`.
@MainActor
enum AdConsentManager {
    private(set) static var isStarted = false

    static func requestConsentThenStartAds() async {
        guard !isStarted else { return }

        let parameters = RequestParameters()
        // Pour tester le formulaire EEE depuis n'importe où, décommente :
        // #if DEBUG
        // let debugSettings = DebugSettings()
        // debugSettings.geography = .EEA
        // parameters.debugSettings = debugSettings
        // #endif

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            if let rootVC = UIApplication.rootViewController {
                // N'affiche le formulaire QUE si requis (EEE) et pas déjà répondu.
                try await ConsentForm.loadAndPresentIfRequired(from: rootVC)
            }
        } catch {
            // Hors-ligne ou message UMP non configuré : on ne bloque jamais l'app.
            print("⚠️ Consentement UMP : \(error.localizedDescription)")
        }

        // Apple exige le prompt ATT avant tout suivi (IDFA) → pubs personnalisées.
        await requestTrackingAuthorization()

        guard ConsentInformation.shared.canRequestAds else { return }
        await MobileAds.shared.start()
        isStarted = true
        await RewardedAdManager.shared.loadAd()   // le pain au four dès l'ouverture
    }

    /// Demande l'autorisation de suivi (App Tracking Transparency).
    ///
    /// Deux pièges : le prompt n'apparaît **qu'une seule fois** dans la vie de
    /// l'app (d'où le garde `.notDetermined`), et il est ignoré en silence si
    /// l'app n'est pas encore `.active` — ce qui arrive au démarrage à froid.
    private static func requestTrackingAuthorization() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        if UIApplication.shared.applicationState != .active {
            try? await Task.sleep(for: .milliseconds(600))
        }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
}
