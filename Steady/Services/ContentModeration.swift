import Foundation

/// Motif d'un signalement (règle App Store 1.2).
enum ReportReason: String, CaseIterable, Identifiable {
    case harassment, hate, sexual, spam, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .harassment: return L("Harcèlement ou intimidation")
        case .hate:       return L("Propos haineux")
        case .sexual:     return L("Contenu sexuel ou choquant")
        case .spam:       return L("Spam ou arnaque")
        case .other:      return L("Autre")
        }
    }
}

/// Filtrage des contenus offensants.
///
/// Apple (règle 1.2) exige un **filtre** en plus du signalement et du blocage.
/// Volontairement conservateur : on bloque une liste courte de termes sans
/// ambiguïté, avec correspondance sur mot entier. Un filtre trop large ferait
/// plus de dégâts (faux positifs sur des messages légitimes) qu'il n'en évite.
enum ContentModeration {

    /// Termes refusés (fr/en/es/pt). Liste volontairement restreinte aux insultes
    /// et propos haineux non ambigus.
    ///
    /// Écartés exprès, car ce sont des mots légitimes dans les langues que l'app
    /// supporte (et la normalisation retire les accents) :
    /// « retard » (fr : être en retard), « negro » (es/pt : la couleur noire),
    /// « rape » (fr : râpe/râper). Les bloquer punirait des messages innocents.
    private static let blocked: Set<String> = [
        // fr
        "connard", "connasse", "salope", "pute", "putain", "enculé", "encule",
        "pédé", "pede", "bougnoule", "youpin", "tarlouze", "batard", "bâtard",
        // en
        "fuck", "fucker", "fucking", "shit", "bitch", "cunt", "whore", "faggot",
        "nigger", "nigga",
        // es
        "puta", "puto", "cabrón", "cabron", "gilipollas", "maricón", "maricon", "mierda",
        // pt
        "caralho", "viado", "merda", "buceta",
    ]

    /// Normalise pour déjouer les contournements simples : casse, accents,
    /// et substitutions type « c0nnard » / « sh!t ».
    private static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        var s = ""
        for ch in folded {
            switch ch {
            case "0": s.append("o")
            case "1", "!", "|": s.append("i")
            case "3": s.append("e")
            case "4", "@": s.append("a")
            case "5", "$": s.append("s")
            case "7": s.append("t")
            default: s.append(ch)
            }
        }
        return s
    }

    /// Le texte contient-il un terme interdit ? (correspondance sur mot entier)
    static func containsObjectionable(_ text: String) -> Bool {
        let words = normalize(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let normalizedBlocked = Set(blocked.map { normalize($0) })
        return words.contains { normalizedBlocked.contains($0) }
    }

    /// Message d'erreur à afficher quand un envoi est refusé.
    static var rejectionMessage: String {
        L("Ce message contient des propos offensants. Steady applique une tolérance zéro.")
    }
}
