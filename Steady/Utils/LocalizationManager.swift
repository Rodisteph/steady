import SwiftUI

/// Gère la langue choisie dans l'app (Système / Français / English).
///
/// - `locale` est injecté dans l'environnement SwiftUI (formatage + textes).
/// - `bundle` sert aux chaînes dynamiques `String(localized:bundle:)`.
/// - On force aussi `AppleLanguages` pour rester cohérent au prochain lancement.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    enum Language: String, CaseIterable, Identifiable {
        case system, fr, en, es, pt
        var id: String { rawValue }

        /// Libellé affiché dans le sélecteur.
        var label: String {
            switch self {
            case .system: return L("Système")
            case .fr: return "Français"
            case .en: return "English"
            case .es: return "Español"
            case .pt: return "Português"
            }
        }
    }

    var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "app_language")
            applyAppleLanguages()
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? Language.system.rawValue
        self.language = Language(rawValue: saved) ?? .system
    }

    /// Locale à injecter dans l'environnement.
    var locale: Locale {
        switch language {
        case .system: return .autoupdatingCurrent
        case .fr: return Locale(identifier: "fr")
        case .en: return Locale(identifier: "en")
        case .es: return Locale(identifier: "es")
        case .pt: return Locale(identifier: "pt")
        }
    }

    /// Bundle de la langue choisie (pour les chaînes dynamiques).
    var bundle: Bundle {
        guard language != .system,
              let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    private func applyAppleLanguages() {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .fr, .en, .es, .pt:
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}

/// Raccourci pour localiser une chaîne dynamique selon la langue choisie dans l'app.
///
/// Cas particulier du **français** : c'est la langue source du catalogue, donc il n'existe
/// pas de `fr.lproj`. Si on cherchait dans le bundle par défaut, on retomberait sur la table
/// de la langue système (ex. anglais) → « Good afternoon » au lieu de « Bon après-midi ».
/// On force donc le repli sur la clé elle-même (qui EST déjà le texte français) en visant
/// une table de traduction inexistante.
func L(_ value: String.LocalizationValue) -> String {
    let manager = LocalizationManager.shared
    if manager.language == .fr {
        return String(localized: value, table: "__source_fr__", bundle: .main, locale: Locale(identifier: "fr"))
    }
    return String(localized: value, bundle: manager.bundle, locale: manager.locale)
}
