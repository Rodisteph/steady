import SwiftUI

/// Catégories de la bibliothèque de routines.
enum RoutineCategory: String, CaseIterable, Identifiable {
    case fitness, running, sleep, morning, meditation, reading, productivity, coding, eating, minimalism, hydration

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .fitness: return "Fitness"
        case .running: return "Course"
        case .sleep: return "Sommeil"
        case .morning: return "Matin"
        case .meditation: return "Méditation"
        case .reading: return "Lecture"
        case .productivity: return "Productivité"
        case .coding: return "Code"
        case .eating: return "Alimentation"
        case .minimalism: return "Minimalisme"
        case .hydration: return "Hydratation"
        }
    }

    var icon: String {
        switch self {
        case .fitness: return "dumbbell.fill"
        case .running: return "figure.run"
        case .sleep: return "moon.fill"
        case .morning: return "sunrise.fill"
        case .meditation: return "brain.head.profile"
        case .reading: return "book.fill"
        case .productivity: return "bolt.fill"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .eating: return "fork.knife"
        case .minimalism: return "leaf.fill"
        case .hydration: return "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .fitness: return Color(red: 0.90, green: 0.45, blue: 0.40)
        case .running: return Color(red: 0.95, green: 0.62, blue: 0.30)
        case .sleep: return Color(red: 0.45, green: 0.47, blue: 0.78)
        case .morning: return Color(red: 0.96, green: 0.72, blue: 0.35)
        case .meditation: return Color(red: 0.55, green: 0.62, blue: 0.85)
        case .reading: return Color(red: 0.55, green: 0.45, blue: 0.78)
        case .productivity: return Color(red: 0.36, green: 0.66, blue: 0.60)
        case .coding: return Color(red: 0.40, green: 0.55, blue: 0.70)
        case .eating: return Color(red: 0.55, green: 0.72, blue: 0.45)
        case .minimalism: return Color(red: 0.47, green: 0.60, blue: 0.54)
        case .hydration: return Color(red: 0.40, green: 0.70, blue: 0.85)
        }
    }
}

/// Une routine = un ensemble d'habitudes prêtes à installer.
struct RoutineTemplate: Identifiable {
    let id = UUID()
    let category: RoutineCategory
    let name: LocalizedStringKey
    let summary: LocalizedStringKey
    let duration: LocalizedStringKey
    let level: Level
    let icon: String
    let habits: [HabitSpec]

    struct HabitSpec: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        var goal: Int = 1
        var unit: String = ""
    }

    enum Level: Identifiable {
        case beginner, intermediate, advanced
        var id: Self { self }
        var label: LocalizedStringKey {
            switch self {
            case .beginner: return "Débutant"
            case .intermediate: return "Intermédiaire"
            case .advanced: return "Avancé"
            }
        }
        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }
    }
}

/// Catalogue statique (on-device, sans réseau).
enum RoutineCatalog {
    static let all: [RoutineTemplate] = [
        RoutineTemplate(category: .fitness, name: "Remise en forme", summary: "Bouge un peu chaque jour, sans matériel.", duration: "10–15 min", level: .beginner, icon: "dumbbell.fill", habits: [
            .init(name: String(localized: "Pompes"), icon: "figure.strengthtraining.traditional", goal: 20, unit: String(localized: "pompes")),
            .init(name: String(localized: "Gainage"), icon: "figure.core.training"),
            .init(name: String(localized: "Étirements"), icon: "figure.flexibility")
        ]),
        RoutineTemplate(category: .running, name: "Débuter la course", summary: "Lance-toi en douceur vers la course régulière.", duration: "20 min", level: .beginner, icon: "figure.run", habits: [
            .init(name: String(localized: "Courir 20 min"), icon: "figure.run"),
            .init(name: String(localized: "Échauffement"), icon: "figure.cooldown"),
            .init(name: String(localized: "Boire de l'eau"), icon: "drop.fill", goal: 6, unit: String(localized: "verres"))
        ]),
        RoutineTemplate(category: .sleep, name: "Mieux dormir", summary: "Des soirées plus calmes pour un meilleur sommeil.", duration: "Soir", level: .beginner, icon: "moon.fill", habits: [
            .init(name: String(localized: "Pas d'écran avant le coucher"), icon: "moon.fill"),
            .init(name: String(localized: "Au lit avant 23h"), icon: "bed.double.fill"),
            .init(name: String(localized: "Lecture 10 min"), icon: "book.fill")
        ]),
        RoutineTemplate(category: .morning, name: "Routine du matin", summary: "Commence la journée du bon pied.", duration: "Matin", level: .beginner, icon: "sunrise.fill", habits: [
            .init(name: String(localized: "Faire le lit"), icon: "bed.double.fill"),
            .init(name: String(localized: "Boire un verre d'eau"), icon: "drop.fill"),
            .init(name: String(localized: "Planifier ma journée"), icon: "star.fill")
        ]),
        RoutineTemplate(category: .meditation, name: "Pleine conscience", summary: "Quelques minutes de calme par jour.", duration: "10 min", level: .beginner, icon: "brain.head.profile", habits: [
            .init(name: String(localized: "Méditer"), icon: "brain.head.profile", goal: 10, unit: String(localized: "min")),
            .init(name: String(localized: "Respiration"), icon: "wind"),
            .init(name: String(localized: "Gratitude"), icon: "heart.fill")
        ]),
        RoutineTemplate(category: .reading, name: "Lire plus", summary: "Retrouve le plaisir de lire chaque jour.", duration: "15 min", level: .beginner, icon: "book.fill", habits: [
            .init(name: String(localized: "Lire 10 pages"), icon: "book.fill", goal: 10, unit: String(localized: "pages"))
        ]),
        RoutineTemplate(category: .productivity, name: "Productivité", summary: "Avance sur ce qui compte vraiment.", duration: "Journée", level: .intermediate, icon: "bolt.fill", habits: [
            .init(name: String(localized: "Tâche prioritaire"), icon: "bolt.fill"),
            .init(name: String(localized: "Pas de réseaux le matin"), icon: "sun.max.fill")
        ]),
        RoutineTemplate(category: .coding, name: "Coder chaque jour", summary: "Progresse en développement, petit à petit.", duration: "30 min", level: .intermediate, icon: "chevron.left.forwardslash.chevron.right", habits: [
            .init(name: String(localized: "Coder 30 min"), icon: "chevron.left.forwardslash.chevron.right", goal: 30, unit: String(localized: "min")),
            .init(name: String(localized: "Apprendre un concept"), icon: "brain.head.profile")
        ]),
        RoutineTemplate(category: .eating, name: "Manger sainement", summary: "De meilleures habitudes alimentaires.", duration: "Journée", level: .beginner, icon: "fork.knife", habits: [
            .init(name: String(localized: "Fruits & légumes"), icon: "fork.knife", goal: 5, unit: String(localized: "portions")),
            .init(name: String(localized: "Pas de sucre ajouté"), icon: "leaf.fill")
        ]),
        RoutineTemplate(category: .minimalism, name: "Minimalisme", summary: "Allège ton quotidien, un objet à la fois.", duration: "5 min", level: .beginner, icon: "leaf.fill", habits: [
            .init(name: String(localized: "Désencombrer 1 objet"), icon: "shippingbox.fill"),
            .init(name: String(localized: "Pas d'achat impulsif"), icon: "hand.raised.fill")
        ]),
        RoutineTemplate(category: .hydration, name: "Hydratation", summary: "Bois assez d'eau, tous les jours.", duration: "Journée", level: .beginner, icon: "drop.fill", habits: [
            .init(name: String(localized: "Boire de l'eau"), icon: "drop.fill", goal: 8, unit: String(localized: "verres"))
        ]),

        // --- Routines supplémentaires ---
        RoutineTemplate(category: .fitness, name: "Musculation maison", summary: "Renforce-toi sans salle, en progressant.", duration: "20–30 min", level: .advanced, icon: "figure.strengthtraining.traditional", habits: [
            .init(name: String(localized: "Pompes"), icon: "figure.strengthtraining.traditional", goal: 40, unit: String(localized: "pompes")),
            .init(name: String(localized: "Squats"), icon: "figure.cross.training", goal: 30, unit: String(localized: "squats")),
            .init(name: String(localized: "Gainage 1 min"), icon: "figure.core.training")
        ]),
        RoutineTemplate(category: .running, name: "Objectif 5 km", summary: "Construis ton endurance jusqu'aux 5 km.", duration: "30 min", level: .intermediate, icon: "figure.run", habits: [
            .init(name: String(localized: "Courir 30 min"), icon: "figure.run"),
            .init(name: String(localized: "Étirements post-course"), icon: "figure.flexibility")
        ]),
        RoutineTemplate(category: .meditation, name: "Soir zen", summary: "Relâche la pression avant de dormir.", duration: "Soir", level: .beginner, icon: "moon.stars.fill", habits: [
            .init(name: String(localized: "Respiration 4-7-8"), icon: "wind"),
            .init(name: String(localized: "Journal du soir"), icon: "book.closed.fill"),
            .init(name: String(localized: "Gratitude"), icon: "heart.fill")
        ]),
        RoutineTemplate(category: .productivity, name: "Deep Work", summary: "Des sessions de concentration profonde.", duration: "Journée", level: .advanced, icon: "brain.head.profile", habits: [
            .init(name: String(localized: "Session focus 90 min"), icon: "timer"),
            .init(name: String(localized: "Téléphone en mode avion"), icon: "airplane"),
            .init(name: String(localized: "Revue du soir"), icon: "checklist")
        ]),
        RoutineTemplate(category: .morning, name: "Réveil énergique", summary: "Un matin qui te met en mouvement.", duration: "Matin", level: .intermediate, icon: "sun.max.fill", habits: [
            .init(name: String(localized: "Étirements au réveil"), icon: "figure.flexibility"),
            .init(name: String(localized: "Lumière du jour 10 min"), icon: "sun.max.fill"),
            .init(name: String(localized: "Petit-déjeuner sain"), icon: "fork.knife")
        ]),
        RoutineTemplate(category: .minimalism, name: "Détox digitale", summary: "Reprends le contrôle de ton temps d'écran.", duration: "Journée", level: .intermediate, icon: "iphone.slash", habits: [
            .init(name: String(localized: "Pas de réseaux avant midi"), icon: "iphone.slash"),
            .init(name: String(localized: "30 min sans téléphone"), icon: "hourglass")
        ]),
        RoutineTemplate(category: .reading, name: "Lecture du soir", summary: "Termine la journée avec un livre.", duration: "20 min", level: .beginner, icon: "book.closed.fill", habits: [
            .init(name: String(localized: "Lire 20 pages"), icon: "book.fill", goal: 20, unit: String(localized: "pages")),
            .init(name: String(localized: "Noter une idée"), icon: "pencil")
        ]),
        RoutineTemplate(category: .eating, name: "Équilibre alimentaire", summary: "Mange mieux, sans frustration.", duration: "Journée", level: .intermediate, icon: "leaf.fill", habits: [
            .init(name: String(localized: "5 fruits & légumes"), icon: "fork.knife", goal: 5, unit: String(localized: "portions")),
            .init(name: String(localized: "Boire 8 verres d'eau"), icon: "drop.fill", goal: 8, unit: String(localized: "verres")),
            .init(name: String(localized: "Pas de grignotage"), icon: "hand.raised.fill")
        ]),

        // --- Routines Premium (niveau avancé) ---
        RoutineTemplate(category: .morning, name: "Miracle Morning", summary: "La routine matinale des grands ambitieux.", duration: "60 min", level: .advanced, icon: "alarm.fill", habits: [
            .init(name: String(localized: "Réveil à 6h"), icon: "alarm.fill"),
            .init(name: String(localized: "Méditer 10 min"), icon: "brain.head.profile", goal: 10, unit: String(localized: "min")),
            .init(name: String(localized: "Sport 20 min"), icon: "figure.run", goal: 20, unit: String(localized: "min")),
            .init(name: String(localized: "Écrire ses objectifs"), icon: "pencil")
        ]),
        RoutineTemplate(category: .running, name: "Objectif 10 km", summary: "Passe au niveau supérieur en endurance.", duration: "45 min", level: .advanced, icon: "figure.run", habits: [
            .init(name: String(localized: "Courir 45 min"), icon: "figure.run", goal: 45, unit: String(localized: "min")),
            .init(name: String(localized: "Renforcement jambes"), icon: "figure.cross.training"),
            .init(name: String(localized: "Étirements post-course"), icon: "figure.flexibility")
        ]),
        RoutineTemplate(category: .sleep, name: "Sommeil de champion", summary: "Le protocole complet d'un sommeil réparateur.", duration: "Soir", level: .advanced, icon: "moon.zzz.fill", habits: [
            .init(name: String(localized: "Au lit à 22h30"), icon: "bed.double.fill"),
            .init(name: String(localized: "Pas d'écran 1h avant"), icon: "iphone.slash"),
            .init(name: String(localized: "Réveil à heure fixe"), icon: "alarm.fill")
        ]),
        RoutineTemplate(category: .meditation, name: "Esprit d'acier", summary: "Méditation profonde et pleine conscience au quotidien.", duration: "25 min", level: .advanced, icon: "figure.mind.and.body", habits: [
            .init(name: String(localized: "Méditer 20 min"), icon: "brain.head.profile", goal: 20, unit: String(localized: "min")),
            .init(name: String(localized: "Marche consciente"), icon: "figure.walk"),
            .init(name: String(localized: "Journal de gratitude"), icon: "heart.fill")
        ]),
        RoutineTemplate(category: .coding, name: "Side project", summary: "Fais avancer ton projet perso, chaque jour.", duration: "1 h", level: .advanced, icon: "hammer.fill", habits: [
            .init(name: String(localized: "1h sur mon projet"), icon: "chevron.left.forwardslash.chevron.right", goal: 60, unit: String(localized: "min")),
            .init(name: String(localized: "Un commit par jour"), icon: "checkmark.seal.fill"),
            .init(name: String(localized: "Veille tech 15 min"), icon: "newspaper.fill", goal: 15, unit: String(localized: "min"))
        ]),
        RoutineTemplate(category: .eating, name: "Nutrition d'athlète", summary: "Mange comme un sportif qui vise la performance.", duration: "Journée", level: .advanced, icon: "carrot.fill", habits: [
            .init(name: String(localized: "Protéines à chaque repas"), icon: "fork.knife"),
            .init(name: String(localized: "8 verres d'eau"), icon: "drop.fill", goal: 8, unit: String(localized: "verres")),
            .init(name: String(localized: "Zéro alcool"), icon: "hand.raised.fill"),
            .init(name: String(localized: "Légumes à chaque repas"), icon: "leaf.fill")
        ]),
        RoutineTemplate(category: .productivity, name: "Maîtrise du temps", summary: "Organise tes journées comme un pro.", duration: "Journée", level: .advanced, icon: "calendar.badge.checkmark", habits: [
            .init(name: String(localized: "Planifier demain la veille"), icon: "calendar"),
            .init(name: String(localized: "Tâche difficile avant 10h"), icon: "bolt.fill"),
            .init(name: String(localized: "Inbox zéro"), icon: "envelope.fill")
        ]),
        RoutineTemplate(category: .minimalism, name: "Reset digital", summary: "Décroche vraiment des écrans, jour après jour.", duration: "Journée", level: .advanced, icon: "iphone.slash", habits: [
            .init(name: String(localized: "Pas de téléphone au réveil"), icon: "sunrise.fill"),
            .init(name: String(localized: "2h sans écran le soir"), icon: "hourglass"),
            .init(name: String(localized: "Une soirée 100% déconnectée"), icon: "moon.stars.fill")
        ])
    ]
}
