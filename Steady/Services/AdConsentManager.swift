import GoogleMobileAds
import UserMessagingPlatform
import UIKit

/// Consentement RGPD (UMP) PUIS démarrage du SDK AdMob — dans cet ordre, exigé
/// par Google pour l'EEE (France/Espagne/Portugal inclus).
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

        guard ConsentInformation.shared.canRequestAds else { return }
        await MobileAds.shared.start()
        isStarted = true
        await RewardedAdManager.shared.loadAd()   // le pain au four dès l'ouverture
    }
}
