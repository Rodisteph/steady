import SwiftUI

/// Catégories de la bibliothèque de routines.
enum RoutineCategory: String, CaseIterable, Identifiable {
    case fitness, running, sleep, morning, meditation, reading, productivity, coding, eating, minimalism, hydration, adulting

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
        case .adulting: return "Vie d'adulte"
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
        case .adulting: return "house.fill"
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
        case .adulting: return Color(red: 0.72, green: 0.52, blue: 0.35)
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
            .init(name: L("Pompes"), icon: "figure.strengthtraining.traditional", goal: 20, unit: L("pompes")),
            .init(name: L("Gainage"), icon: "figure.core.training"),
            .init(name: L("Étirements"), icon: "figure.flexibility")
        ]),
        RoutineTemplate(category: .running, name: "Débuter la course", summary: "Lance-toi en douceur vers la course régulière.", duration: "20 min", level: .beginner, icon: "figure.run", habits: [
            .init(name: L("Courir 20 min"), icon: "figure.run"),
            .init(name: L("Échauffement"), icon: "figure.cooldown"),
            .init(name: L("Boire de l'eau"), icon: "drop.fill", goal: 6, unit: L("verres"))
        ]),
        RoutineTemplate(category: .sleep, name: "Mieux dormir", summary: "Des soirées plus calmes pour un meilleur sommeil.", duration: "Soir", level: .beginner, icon: "moon.fill", habits: [
            .init(name: L("Pas d'écran avant le coucher"), icon: "moon.fill"),
            .init(name: L("Au lit avant 23h"), icon: "bed.double.fill"),
            .init(name: L("Lecture 10 min"), icon: "book.fill")
        ]),
        RoutineTemplate(category: .morning, name: "Routine du matin", summary: "Commence la journée du bon pied.", duration: "Matin", level: .beginner, icon: "sunrise.fill", habits: [
            .init(name: L("Faire le lit"), icon: "bed.double.fill"),
            .init(name: L("Boire un verre d'eau"), icon: "drop.fill"),
            .init(name: L("Planifier ma journée"), icon: "star.fill")
        ]),
        RoutineTemplate(category: .meditation, name: "Pleine conscience", summary: "Quelques minutes de calme par jour.", duration: "10 min", level: .beginner, icon: "brain.head.profile", habits: [
            .init(name: L("Méditer"), icon: "brain.head.profile", goal: 10, unit: L("min")),
            .init(name: L("Respiration"), icon: "wind"),
            .init(name: L("Gratitude"), icon: "heart.fill")
        ]),
        RoutineTemplate(category: .reading, name: "Lire plus", summary: "Retrouve le plaisir de lire chaque jour.", duration: "15 min", level: .beginner, icon: "book.fill", habits: [
            .init(name: L("Lire 10 pages"), icon: "book.fill", goal: 10, unit: L("pages"))
        ]),
        RoutineTemplate(category: .productivity, name: "Productivité", summary: "Avance sur ce qui compte vraiment.", duration: "Journée", level: .intermediate, icon: "bolt.fill", habits: [
            .init(name: L("Tâche prioritaire"), icon: "bolt.fill"),
            .init(name: L("Pas de réseaux le matin"), icon: "sun.max.fill")
        ]),
        RoutineTemplate(category: .coding, name: "Coder chaque jour", summary: "Progresse en développement, petit à petit.", duration: "30 min", level: .intermediate, icon: "chevron.left.forwardslash.chevron.right", habits: [
            .init(name: L("Coder 30 min"), icon: "chevron.left.forwardslash.chevron.right", goal: 30, unit: L("min")),
            .init(name: L("Apprendre un concept"), icon: "brain.head.profile")
        ]),
        RoutineTemplate(category: .eating, name: "Manger sainement", summary: "De meilleures habitudes alimentaires.", duration: "Journée", level: .beginner, icon: "fork.knife", habits: [
            .init(name: L("Fruits & légumes"), icon: "fork.knife", goal: 5, unit: L("portions")),
            .init(name: L("Pas de sucre ajouté"), icon: "leaf.fill")
        ]),
        RoutineTemplate(category: .minimalism, name: "Minimalisme", summary: "Allège ton quotidien, un objet à la fois.", duration: "5 min", level: .beginner, icon: "leaf.fill", habits: [
            .init(name: L("Désencombrer 1 objet"), icon: "shippingbox.fill"),
            .init(name: L("Pas d'achat impulsif"), icon: "hand.raised.fill")
        ]),
        RoutineTemplate(category: .hydration, name: "Hydratation", summary: "Bois assez d'eau, tous les jours.", duration: "Journée", level: .beginner, icon: "drop.fill", habits: [
            .init(name: L("Boire de l'eau"), icon: "drop.fill", goal: 8, unit: L("verres"))
        ]),

        // --- Routines supplémentaires ---
        RoutineTemplate(category: .fitness, name: "Musculation maison", summary: "Renforce-toi sans salle, en progressant.", duration: "20–30 min", level: .advanced, icon: "figure.strengthtraining.traditional", habits: [
            .init(name: L("Pompes"), icon: "figure.strengthtraining.traditional", goal: 40, unit: L("pompes")),
            .init(name: L("Squats"), icon: "figure.cross.training", goal: 30, unit: L("squats")),
            .init(name: L("Gainage 1 min"), icon: "figure.core.training")
        ]),
        RoutineTemplate(category: .running, name: "Objectif 5 km", summary: "Construis ton endurance jusqu'aux 5 km.", duration: "30 min", level: .intermediate, icon: "figure.run", habits: [
            .init(name: L("Courir 30 min"), icon: "figure.run"),
            .init(name: L("Étirements post-course"), icon: "figure.flexibility")
        ]),
        RoutineTemplate(category: .meditation, name: "Soir zen", summary: "Relâche la pression avant de dormir.", duration: "Soir", level: .beginner, icon: "moon.stars.fill", habits: [
            .init(name: L("Respiration 4-7-8"), icon: "wind"),
            .init(name: L("Journal du soir"), icon: "book.closed.fill"),
            .init(name: L("Gratitude"), icon: "heart.fill")
        ]),
        RoutineTemplate(category: .productivity, name: "Deep Work", summary: "Des sessions de concentration profonde.", duration: "Journée", level: .advanced, icon: "brain.head.profile", habits: [
            .init(name: L("Session focus 90 min"), icon: "timer"),
            .init(name: L("Téléphone en mode avion"), icon: "airplane"),
            .init(name: L("Revue du soir"), icon: "checklist")
        ]),
        RoutineTemplate(category: .morning, name: "Réveil énergique", summary: "Un matin qui te met en mouvement.", duration: "Matin", level: .intermediate, icon: "sun.max.fill", habits: [
            .init(name: L("Étirements au réveil"), icon: "figure.flexibility"),
            .init(name: L("Lumière du jour 10 min"), icon: "sun.max.fill"),
            .init(name: L("Petit-déjeuner sain"), icon: "fork.knife")
        ]),
        RoutineTemplate(category: .minimalism, name: "Détox digitale", summary: "Reprends le contrôle de ton temps d'écran.", duration: "Journée", level: .intermediate, icon: "iphone.slash", habits: [
            .init(name: L("Pas de réseaux avant midi"), icon: "iphone.slash"),
            .init(name: L("30 min sans téléphone"), icon: "hourglass")
        ]),
        RoutineTemplate(category: .reading, name: "Lecture du soir", summary: "Termine la journée avec un livre.", duration: "20 min", level: .beginner, icon: "book.closed.fill", habits: [
            .init(name: L("Lire 20 pages"), icon: "book.fill", goal: 20, unit: L("pages")),
            .init(name: L("Noter une idée"), icon: "pencil")
        ]),
        RoutineTemplate(category: .eating, name: "Équilibre alimentaire", summary: "Mange mieux, sans frustration.", duration: "Journée", level: .intermediate, icon: "leaf.fill", habits: [
            .init(name: L("5 fruits & légumes"), icon: "fork.knife", goal: 5, unit: L("portions")),
            .init(name: L("Boire 8 verres d'eau"), icon: "drop.fill", goal: 8, unit: L("verres")),
            .init(name: L("Pas de grignotage"), icon: "hand.raised.fill")
        ]),

        // --- Routines Premium (niveau avancé) ---
        RoutineTemplate(category: .morning, name: "Miracle Morning", summary: "La routine matinale des grands ambitieux.", duration: "60 min", level: .advanced, icon: "alarm.fill", habits: [
            .init(name: L("Réveil à 6h"), icon: "alarm.fill"),
            .init(name: L("Méditer 10 min"), icon: "brain.head.profile", goal: 10, unit: L("min")),
            .init(name: L("Sport 20 min"), icon: "figure.run", goal: 20, unit: L("min")),
            .init(name: L("Écrire ses objectifs"), icon: "pencil")
        ]),
        RoutineTemplate(category: .running, name: "Objectif 10 km", summary: "Passe au niveau supérieur en endurance.", duration: "45 min", level: .advanced, icon: "figure.run", habits: [
            .init(name: L("Courir 45 min"), icon: "figure.run", goal: 45, unit: L("min")),
            .init(name: L("Renforcement jambes"), icon: "figure.cross.training"),
            .init(name: L("Étirements post-course"), icon: "figure.flexibility")
        ]),
        RoutineTemplate(category: .sleep, name: "Sommeil de champion", summary: "Le protocole complet d'un sommeil réparateur.", duration: "Soir", level: .advanced, icon: "moon.zzz.fill", habits: [
            .init(name: L("Au lit à 22h30"), icon: "bed.double.fill"),
            .init(name: L("Pas d'écran 1h avant"), icon: "iphone.slash"),
            .init(name: L("Réveil à heure fixe"), icon: "alarm.fill")
        ]),
        RoutineTemplate(category: .meditation, name: "Esprit d'acier", summary: "Méditation profonde et pleine conscience au quotidien.", duration: "25 min", level: .advanced, icon: "figure.mind.and.body", habits: [
            .init(name: L("Méditer 20 min"), icon: "brain.head.profile", goal: 20, unit: L("min")),
            .init(name: L("Marche consciente"), icon: "figure.walk"),
            .init(name: L("Journal de gratitude"), icon: "heart.fill")
        ]),
        RoutineTemplate(category: .coding, name: "Side project", summary: "Fais avancer ton projet perso, chaque jour.", duration: "1 h", level: .advanced, icon: "hammer.fill", habits: [
            .init(name: L("1h sur mon projet"), icon: "chevron.left.forwardslash.chevron.right", goal: 60, unit: L("min")),
            .init(name: L("Un commit par jour"), icon: "checkmark.seal.fill"),
            .init(name: L("Veille tech 15 min"), icon: "newspaper.fill", goal: 15, unit: L("min"))
        ]),
        RoutineTemplate(category: .eating, name: "Nutrition d'athlète", summary: "Mange comme un sportif qui vise la performance.", duration: "Journée", level: .advanced, icon: "carrot.fill", habits: [
            .init(name: L("Protéines à chaque repas"), icon: "fork.knife"),
            .init(name: L("8 verres d'eau"), icon: "drop.fill", goal: 8, unit: L("verres")),
            .init(name: L("Zéro alcool"), icon: "hand.raised.fill"),
            .init(name: L("Légumes à chaque repas"), icon: "leaf.fill")
        ]),
        RoutineTemplate(category: .productivity, name: "Maîtrise du temps", summary: "Organise tes journées comme un pro.", duration: "Journée", level: .advanced, icon: "calendar.badge.checkmark", habits: [
            .init(name: L("Planifier demain la veille"), icon: "calendar"),
            .init(name: L("Tâche difficile avant 10h"), icon: "bolt.fill"),
            .init(name: L("Inbox zéro"), icon: "envelope.fill")
        ]),
        RoutineTemplate(category: .minimalism, name: "Reset digital", summary: "Décroche vraiment des écrans, jour après jour.", duration: "Journée", level: .advanced, icon: "iphone.slash", habits: [
            .init(name: L("Pas de téléphone au réveil"), icon: "sunrise.fill"),
            .init(name: L("2h sans écran le soir"), icon: "hourglass"),
            .init(name: L("Une soirée 100% déconnectée"), icon: "moon.stars.fill")
        ]),

        // --- Vie d'adulte (ménage, papiers, budget) ---
        RoutineTemplate(category: .adulting, name: "Maison au carré", summary: "Un intérieur propre sans y passer le dimanche.", duration: "15 min", level: .beginner, icon: "house.fill", habits: [
            .init(name: L("Faire le lit"), icon: "bed.double.fill"),
            .init(name: L("10 min de rangement"), icon: "shippingbox.fill", goal: 10, unit: L("min")),
            .init(name: L("Vaisselle du soir faite"), icon: "sink.fill")
        ]),
        RoutineTemplate(category: .adulting, name: "Paperasse zéro stress", summary: "Fini la pile de courrier qui te juge.", duration: "10 min", level: .intermediate, icon: "tray.full.fill", habits: [
            .init(name: L("Traiter le courrier du jour"), icon: "envelope.open.fill"),
            .init(name: L("Classer un document"), icon: "folder.fill"),
            .init(name: L("10 min de mails admin"), icon: "at", goal: 10, unit: L("min"))
        ]),
        RoutineTemplate(category: .adulting, name: "Budget d'adulte", summary: "Sache où part ton argent, sans tableur géant.", duration: "5 min", level: .intermediate, icon: "eurosign.circle.fill", habits: [
            .init(name: L("Noter mes dépenses"), icon: "pencil.and.list.clipboard"),
            .init(name: L("Vérifier mon compte"), icon: "creditcard.fill"),
            .init(name: L("Pas d'achat impulsif"), icon: "hand.raised.fill")
        ]),
        RoutineTemplate(category: .adulting, name: "Adulte niveau expert", summary: "Le pack complet : maison, papiers, repas, linge.", duration: "Journée", level: .advanced, icon: "checkmark.seal.fill", habits: [
            .init(name: L("Ranger 15 min"), icon: "shippingbox.fill", goal: 15, unit: L("min")),
            .init(name: L("Un papier traité"), icon: "doc.text.fill"),
            .init(name: L("Repas maison"), icon: "fork.knife"),
            .init(name: L("Linge à jour"), icon: "tshirt.fill")
        ]),

        // --- Routines Premium supplémentaires ---
        RoutineTemplate(category: .fitness, name: "75 Hard soft", summary: "La discipline ultime, version tenable.", duration: "Journée", level: .advanced, icon: "flame.fill", habits: [
            .init(name: L("2 séances de sport"), icon: "figure.run"),
            .init(name: L("Boire 3 L d'eau"), icon: "drop.fill", goal: 12, unit: L("verres")),
            .init(name: L("Lire 10 pages"), icon: "book.fill", goal: 10, unit: L("pages")),
            .init(name: L("Régime propre"), icon: "leaf.fill")
        ]),
        RoutineTemplate(category: .morning, name: "Routine du champion", summary: "Le matin des sportifs de haut niveau.", duration: "Matin", level: .advanced, icon: "trophy.fill", habits: [
            .init(name: L("Réveil sans snooze"), icon: "alarm.fill"),
            .init(name: L("Eau + électrolytes"), icon: "drop.fill"),
            .init(name: L("Mobilité 10 min"), icon: "figure.flexibility", goal: 10, unit: L("min")),
            .init(name: L("Douche froide"), icon: "snowflake")
        ]),
        RoutineTemplate(category: .reading, name: "Cerveau affûté", summary: "Entraîne ton esprit comme un muscle.", duration: "30 min", level: .advanced, icon: "brain.head.profile", habits: [
            .init(name: L("Lecture 20 min"), icon: "book.fill", goal: 20, unit: L("min")),
            .init(name: L("Apprendre un mot"), icon: "character.book.closed.fill"),
            .init(name: L("Résoudre une énigme"), icon: "puzzlepiece.fill"),
            .init(name: L("Méditer 10 min"), icon: "brain.head.profile", goal: 10, unit: L("min"))
        ]),
        RoutineTemplate(category: .sleep, name: "Récupération pro", summary: "Optimise ton sommeil comme un athlète.", duration: "Soir", level: .advanced, icon: "moon.zzz.fill", habits: [
            .init(name: L("Pas de caféine après 14h"), icon: "cup.and.saucer.fill"),
            .init(name: L("Écrans coupés à 22h"), icon: "iphone.slash"),
            .init(name: L("Chambre fraîche et sombre"), icon: "thermometer.snowflake"),
            .init(name: L("8h de sommeil"), icon: "bed.double.fill")
        ])
    ]
}
