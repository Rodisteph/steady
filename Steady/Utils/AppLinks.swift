import Foundation

/// Source unique des liens légaux affichés dans l'app.
///
/// ⚠️ AVANT SOUMISSION APP STORE : remplacez `domain` par votre vrai domaine
/// et hébergez les pages `privacy` et `terms` (modèles fournis dans
/// PRIVACY.md et TERMS.md à la racine du projet). Apple **exige** une URL de
/// politique de confidentialité valide et accessible.
enum AppLinks {
    /// Base des pages légales (GitHub Pages). Les pages doivent être publiées à
    /// `/privacy` et `/terms` sous cette base.
    private static let domain = "https://rodisteph.github.io/steady"

    static var privacyPolicy: URL { URL(string: "\(domain)/privacy")! }
    static var termsOfUse: URL { URL(string: "\(domain)/terms")! }
}
