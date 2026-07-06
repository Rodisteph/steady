import Foundation

/// Décide QUAND demander une note App Store (le système affiche la popup).
/// Règles : jamais avant 3 jours d'utilisation, jamais deux fois pour la même
/// version de l'app, et uniquement à un moment de joie (célébration).
enum ReviewRequester {
    private static let firstLaunchKey = "steady_first_launch"
    private static let askedVersionKey = "steady_review_asked_version"

    /// À appeler au démarrage : mémorise la date de première ouverture.
    static func registerLaunch() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(Date(), forKey: firstLaunchKey)
        }
    }

    /// `true` si c'est le bon moment pour demander (et marque la version comme demandée).
    static func shouldAsk() -> Bool {
        let defaults = UserDefaults.standard
        guard let first = defaults.object(forKey: firstLaunchKey) as? Date else {
            registerLaunch()
            return false
        }
        // Au moins 3 jours d'usage : l'utilisateur a vu la valeur de l'app.
        guard Date().timeIntervalSince(first) >= 3 * 86_400 else { return false }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        guard defaults.string(forKey: askedVersionKey) != version else { return false }

        defaults.set(version, forKey: askedVersionKey)
        return true
    }
}
