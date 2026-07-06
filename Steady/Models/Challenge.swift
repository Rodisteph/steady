import SwiftData
import SwiftUI

/// Un défi rejoint par l'utilisateur (persisté).
@Model
final class Challenge {
    var id: UUID = UUID()
    var templateID: String = ""
    var title: String = ""
    var icon: String = "trophy.fill"
    var target: Int = 1
    var unit: String = ""
    var isDaily: Bool = false
    var progress: Int = 0
    var startDate: Date = Date()
    var lastProgressDate: Date?
    var isCompleted: Bool = false

    /// Habitude liée (les défis quotidiens progressent automatiquement avec elle).
    var habitID: UUID?
    /// Date limite pour réussir le défi.
    var deadline: Date = Date()
    /// Récompense déjà attribuée (évite de la donner deux fois).
    var rewarded: Bool = false
    /// Identifiant du défi partagé sur Firebase (nil = défi purement local).
    var sharedID: String?

    init(template: ChallengeTemplate) {
        self.id = UUID()
        self.templateID = template.id
        self.title = template.name
        self.icon = template.icon
        self.target = template.target
        self.unit = template.unit
        self.isDaily = template.isDaily
        self.progress = 0
        self.startDate = Date()
        self.lastProgressDate = nil
        self.isCompleted = false
        self.deadline = Calendar.current.date(byAdding: .day, value: template.windowDays, to: Date()) ?? Date()
    }

    /// Défi créé par l'utilisateur (hors catalogue) ou rejoint via une invitation.
    init(customTitle: String, icon: String, target: Int, unit: String, isDaily: Bool, windowDays: Int) {
        self.id = UUID()
        self.templateID = "custom"
        self.title = customTitle
        self.icon = icon
        self.target = target
        self.unit = unit
        self.isDaily = isDaily
        self.progress = 0
        self.startDate = Date()
        self.lastProgressDate = nil
        self.isCompleted = false
        self.deadline = Calendar.current.date(byAdding: .day, value: windowDays, to: Date()) ?? Date()
    }

    /// Récompenses à la réussite (proportionnelles à l'objectif, plafonnées).
    var rewardCoins: Int { min(150, max(20, target)) }
    var rewardXP: Int { min(300, max(40, target * 2)) }

    var ratio: Double { target > 0 ? min(Double(progress) / Double(target), 1) : 0 }
}

/// Modèle d'un défi proposé (catalogue statique).
struct ChallengeTemplate: Identifiable {
    let id: String
    let name: String
    let summary: LocalizedStringKey
    let icon: String
    let color: Color
    let target: Int
    let unit: String
    let isDaily: Bool

    /// Fenêtre de temps pour réussir : quotidien = objectif + marge ; cumulatif = un mois.
    nonisolated var windowDays: Int {
        isDaily ? max(target + 10, Int(ceil(Double(target) * 1.4))) : 30
    }
}

enum ChallengeCatalog {
    /// Recalculé à chaque accès → suit la langue choisie dans l'app (changement à chaud).
    static var all: [ChallengeTemplate] {
        [
            ChallengeTemplate(id: "med30", name: L("30 jours de méditation"),
                              summary: "Médite chaque jour pendant 30 jours.", icon: "brain.head.profile",
                              color: Color(red: 0.55, green: 0.45, blue: 0.80), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "push100", name: L("100 pompes"),
                              summary: "Cumule 100 pompes à ton rythme.", icon: "figure.strengthtraining.traditional",
                              color: Color(red: 0.88, green: 0.42, blue: 0.38), target: 100, unit: L("pompes"), isDaily: false),
            ChallengeTemplate(id: "water21", name: L("Hydratation · 21 jours"),
                              summary: "Bois assez d'eau 21 jours d'affilée.", icon: "drop.fill",
                              color: Color(red: 0.36, green: 0.66, blue: 0.84), target: 21, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "read14", name: L("Lecture · 14 jours"),
                              summary: "Lis 20 minutes chaque jour, 2 semaines.", icon: "book.fill",
                              color: Color(red: 0.80, green: 0.58, blue: 0.32), target: 14, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "nosugar15", name: L("Sans sucre · 15 jours"),
                              summary: "Évite le sucre ajouté pendant 15 jours.", icon: "leaf.fill",
                              color: Color(red: 0.50, green: 0.72, blue: 0.45), target: 15, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "wake21", name: L("Réveil à 6h · 21 jours"),
                              summary: "Lève-toi à 6h pendant 21 jours.", icon: "sunrise.fill",
                              color: Color(red: 0.94, green: 0.70, blue: 0.34), target: 21, unit: L("jours"), isDaily: true),

            // --- Défis supplémentaires ---
            ChallengeTemplate(id: "steps30", name: L("10 000 pas · 30 jours"),
                              summary: "Marche 10 000 pas chaque jour pendant 30 jours.", icon: "figure.walk",
                              color: Color(red: 0.36, green: 0.66, blue: 0.60), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "plank30", name: L("Gainage · 30 jours"),
                              summary: "Tiens la planche chaque jour pendant 30 jours.", icon: "figure.core.training",
                              color: Color(red: 0.88, green: 0.45, blue: 0.40), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "gratitude30", name: L("Gratitude · 30 jours"),
                              summary: "Note une gratitude chaque jour pendant 30 jours.", icon: "heart.fill",
                              color: Color(red: 0.85, green: 0.50, blue: 0.55), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "cold21", name: L("Douche froide · 21 jours"),
                              summary: "Termine ta douche à l'eau froide, 21 jours.", icon: "snowflake",
                              color: Color(red: 0.40, green: 0.70, blue: 0.85), target: 21, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "noscreen21", name: L("Sans écran le matin · 21 jours"),
                              summary: "Pas de téléphone la première heure, 21 jours.", icon: "iphone.slash",
                              color: Color(red: 0.45, green: 0.47, blue: 0.78), target: 21, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "stretch21", name: L("Souplesse · 21 jours"),
                              summary: "Étire-toi 10 minutes chaque jour, 21 jours.", icon: "figure.flexibility",
                              color: Color(red: 0.55, green: 0.62, blue: 0.85), target: 21, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "run50", name: L("50 km ce mois"),
                              summary: "Cumule 50 km de course dans le mois.", icon: "figure.run",
                              color: Color(red: 0.95, green: 0.62, blue: 0.30), target: 50, unit: L("km"), isDaily: false),
            ChallengeTemplate(id: "books4", name: L("4 livres"),
                              summary: "Lis 4 livres à ton rythme.", icon: "books.vertical.fill",
                              color: Color(red: 0.55, green: 0.45, blue: 0.78), target: 4, unit: L("livres"), isDaily: false)
        ]
    }

    static func template(for id: String) -> ChallengeTemplate? {
        all.first { $0.id == id }
    }

    static func color(for id: String) -> Color {
        template(for: id)?.color ?? .accentDeep
    }
}
