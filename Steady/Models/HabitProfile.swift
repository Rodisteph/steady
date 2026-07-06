import SwiftUI

/// Profils proposés à l'onboarding. Chacun pré-charge 3 habitudes.
enum HabitProfile: String, CaseIterable, Identifiable {
    case health
    case learning
    case wellbeing
    case productivity

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .health: return "Santé"
        case .learning: return "Apprentissage"
        case .wellbeing: return "Bien-être"
        case .productivity: return "Productivité"
        }
    }

    var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .learning: return "book.fill"
        case .wellbeing: return "leaf.fill"
        case .productivity: return "bolt.fill"
        }
    }

    /// 3 habitudes pré-remplies, déjà localisées selon la langue de l'app.
    var habits: [(name: String, icon: String)] {
        switch self {
        case .health:
            return [
                (String(localized: "Boire de l'eau"), "drop.fill"),
                (String(localized: "Bouger 30 min"), "figure.run"),
                (String(localized: "Bien dormir"), "moon.fill")
            ]
        case .learning:
            return [
                (String(localized: "Lire 10 pages"), "book.fill"),
                (String(localized: "Réviser"), "pencil"),
                (String(localized: "Apprendre un mot"), "brain.head.profile")
            ]
        case .wellbeing:
            return [
                (String(localized: "Méditer"), "brain.head.profile"),
                (String(localized: "Gratitude"), "heart.fill"),
                (String(localized: "Respirer"), "leaf.fill")
            ]
        case .productivity:
            return [
                (String(localized: "Planifier ma journée"), "star.fill"),
                (String(localized: "Tâche prioritaire"), "bolt.fill"),
                (String(localized: "Pas d'écran le matin"), "sun.max.fill")
            ]
        }
    }
}
