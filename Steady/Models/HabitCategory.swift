import SwiftUI

/// Catégorie (« genre ») d'une habitude — pour regrouper et filtrer d'un coup d'œil.
enum HabitCategory: String, CaseIterable, Identifiable {
    case health, fitness, mind, work, home, social, other

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .health: return "Santé"
        case .fitness: return "Sport"
        case .mind: return "Esprit"
        case .work: return "Travail"
        case .home: return "Maison"
        case .social: return "Social"
        case .other: return "Autre"
        }
    }

    /// Titre en `String` (pour les bulles, qui dessinent du texte brut).
    var titleText: String {
        switch self {
        case .health: return L("Santé")
        case .fitness: return L("Sport")
        case .mind: return L("Esprit")
        case .work: return L("Travail")
        case .home: return L("Maison")
        case .social: return L("Social")
        case .other: return L("Autre")
        }
    }

    var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .fitness: return "figure.run"
        case .mind: return "brain.head.profile"
        case .work: return "briefcase.fill"
        case .home: return "house.fill"
        case .social: return "person.2.fill"
        case .other: return "circle.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .health: return Color(red: 0.85, green: 0.45, blue: 0.50)
        case .fitness: return Color(red: 0.95, green: 0.62, blue: 0.30)
        case .mind: return Color(red: 0.55, green: 0.55, blue: 0.85)
        case .work: return Color(red: 0.40, green: 0.60, blue: 0.75)
        case .home: return Color(red: 0.72, green: 0.55, blue: 0.38)
        case .social: return Color(red: 0.50, green: 0.72, blue: 0.55)
        case .other: return Color(red: 0.55, green: 0.58, blue: 0.60)
        }
    }

    /// Devine la catégorie d'après le nom de l'habitude (auto-classement à la création).
    /// L'utilisateur peut toujours la changer dans le détail.
    static func suggestion(forName name: String) -> HabitCategory {
        let n = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        func has(_ w: [String]) -> Bool { w.contains { n.contains($0) } }

        if has(["courir","course","run","marche","marcher","walk","sport","muscu","gym","pompes","squat",
                "velo","natation","yoga","fitness","workout","gainage","etirement","stretch","football","tennis"]) { return .fitness }
        if has(["eau","boire","water","hydrat","dormir","sommeil","sleep","dent","brosse","vitamine","medicament",
                "sante","health","fruit","legume","manger","repas","sucre","tabac","fumer","cigarette","alcool","peser"]) { return .health }
        if has(["medit","meditat","respir","breath","gratitude","journal","lire","lecture","read","apprendre","learn",
                "langue","etudier","cours","cerveau","calme","pleine conscience","mindful"]) { return .mind }
        if has(["travail","work","projet","code","coder","email","mail","reunion","tache","deadline","etude","boulot",
                "productiv","focus","concentrer"]) { return .work }
        if has(["menage","ranger","rangement","vaisselle","linge","lit","maison","home","nettoyer","courses","cuisiner",
                "papier","facture","budget","depense"]) { return .home }
        if has(["ami","amis","appeler","call","famille","family","message","social","voir","rencontrer","couple"]) { return .social }
        return .other
    }
}

/// Priorité d'une habitude (stockée en Int dans SwiftData : 2 haute, 1 normale, 0 basse).
enum HabitPriority: Int, CaseIterable, Identifiable {
    case low = 0, normal = 1, high = 2

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .high: return "Haute"
        case .normal: return "Normale"
        case .low: return "Basse"
        }
    }

    var icon: String {
        switch self {
        case .high: return "exclamationmark.circle.fill"
        case .normal: return "equal.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .high: return .orange
        case .normal: return .secondary
        case .low: return .secondary.opacity(0.6)
        }
    }
}
