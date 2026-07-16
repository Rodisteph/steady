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
    /// Métrique Apple Santé liée (vide = aucune). Le défi cumulatif progresse tout seul.
    var healthMetricRaw: String = ""
    var healthMetric: HealthMetric? { HealthMetric(rawValue: healthMetricRaw) }

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
        self.healthMetricRaw = template.healthMetric?.rawValue ?? ""
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
    /// Métrique Apple Santé pour l'auto-progression (défis cumulatifs uniquement).
    var healthMetric: HealthMetric? = nil

    /// Fenêtre de temps pour réussir. Quotidien : l'objectif + 3 jours de grâce
    /// (un défi « 21 jours » se joue en ~24 jours, pas 31). Cumulatif : un mois.
    nonisolated var windowDays: Int {
        isDaily ? target + 3 : 30
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
                              summary: "Cumule 50 km de course dans le mois. Suivi via Apple Santé.", icon: "figure.run",
                              color: Color(red: 0.95, green: 0.62, blue: 0.30), target: 50, unit: L("km"), isDaily: false,
                              healthMetric: .distance),
            ChallengeTemplate(id: "books4", name: L("4 livres"),
                              summary: "Lis 4 livres à ton rythme.", icon: "books.vertical.fill",
                              color: Color(red: 0.55, green: 0.45, blue: 0.78), target: 4, unit: L("livres"), isDaily: false),

            // --- Nouveaux défis ---
            ChallengeTemplate(id: "water66", name: L("Nouvelle habitude · 66 jours"),
                              summary: "66 jours pour ancrer une habitude pour de bon.", icon: "checkmark.seal.fill",
                              color: Color(red: 0.36, green: 0.66, blue: 0.60), target: 66, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "noalcohol30", name: L("Sobre · 30 jours"),
                              summary: "Un mois sans alcool. Ton corps te remerciera.", icon: "wineglass",
                              color: Color(red: 0.55, green: 0.45, blue: 0.78), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "tidy30", name: L("Maison rangée · 30 jours"),
                              summary: "10 minutes de rangement chaque jour, 30 jours.", icon: "house.fill",
                              color: Color(red: 0.72, green: 0.52, blue: 0.35), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "save30", name: L("Zéro dépense superflue · 30 jours"),
                              summary: "Pas d'achat impulsif pendant 30 jours.", icon: "eurosign.circle.fill",
                              color: Color(red: 0.50, green: 0.72, blue: 0.45), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "pushup1000", name: L("1000 pompes ce mois"),
                              summary: "Cumule 1000 pompes à ton rythme dans le mois.", icon: "figure.strengthtraining.traditional",
                              color: Color(red: 0.88, green: 0.42, blue: 0.38), target: 1000, unit: L("pompes"), isDaily: false),
            ChallengeTemplate(id: "journal21", name: L("Journal · 21 jours"),
                              summary: "Écris quelques lignes chaque soir, 21 jours.", icon: "book.closed.fill",
                              color: Color(red: 0.61, green: 0.56, blue: 0.77), target: 21, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "walk100", name: L("100 km à pied ce mois"),
                              summary: "Cumule 100 km de marche dans le mois. Suivi via Apple Santé.", icon: "figure.walk",
                              color: Color(red: 0.36, green: 0.66, blue: 0.84), target: 100, unit: L("km"), isDaily: false,
                              healthMetric: .distance),
            ChallengeTemplate(id: "language30", name: L("Une langue · 30 jours"),
                              summary: "Étudie une langue chaque jour pendant 30 jours.", icon: "character.book.closed.fill",
                              color: Color(red: 0.55, green: 0.62, blue: 0.85), target: 30, unit: L("jours"), isDaily: true),

            // --- Santé & bien-être ---
            ChallengeTemplate(id: "notabac30", name: L("Sans tabac · 30 jours"),
                              summary: "30 jours sans fumer. Le plus beau cadeau à tes poumons.", icon: "lungs.fill",
                              color: Color(red: 0.45, green: 0.68, blue: 0.55), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "nosugar30", name: L("Sans sucre ajouté · 30 jours"),
                              summary: "Un mois sans sucre ajouté. Ton énergie va décoller.", icon: "cube.fill",
                              color: Color(red: 0.85, green: 0.55, blue: 0.45), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "nofastfood21", name: L("Sans fast-food · 21 jours"),
                              summary: "21 jours sans fast-food, cuisine maison à la place.", icon: "takeoutbag.and.cup.and.straw.fill",
                              color: Color(red: 0.88, green: 0.50, blue: 0.38), target: 21, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "run100", name: L("100 km de course ce mois"),
                              summary: "Cumule 100 km de course dans le mois. Suivi via Apple Santé.", icon: "figure.run",
                              color: Color(red: 0.90, green: 0.45, blue: 0.35), target: 100, unit: L("km"), isDaily: false,
                              healthMetric: .distance),
            ChallengeTemplate(id: "steps300k", name: L("300 000 pas ce mois"),
                              summary: "Cumule 300 000 pas dans le mois. Suivi via Apple Santé.", icon: "figure.walk",
                              color: Color(red: 0.36, green: 0.66, blue: 0.84), target: 300000, unit: L("pas"), isDaily: false,
                              healthMetric: .steps),
            ChallengeTemplate(id: "sleep21", name: L("Au lit avant 23h · 21 jours"),
                              summary: "Couche-toi avant 23h pendant 21 jours.", icon: "bed.double.fill",
                              color: Color(red: 0.45, green: 0.47, blue: 0.78), target: 21, unit: L("jours"), isDaily: true),

            // --- Encore plus de défis ---
            ChallengeTemplate(id: "exercise500", name: L("500 minutes de sport ce mois"),
                              summary: "Cumule 500 minutes d'exercice ce mois. Suivi via Apple Santé.", icon: "figure.strengthtraining.traditional",
                              color: Color(red: 0.88, green: 0.45, blue: 0.40), target: 500, unit: L("min"), isDaily: false,
                              healthMetric: .exercise),
            ChallengeTemplate(id: "energy10k", name: L("10 000 calories actives ce mois"),
                              summary: "Brûle 10 000 kcal actives ce mois. Suivi via Apple Santé.", icon: "flame.fill",
                              color: Color(red: 0.95, green: 0.55, blue: 0.30), target: 10000, unit: L("kcal"), isDaily: false,
                              healthMetric: .energy),
            ChallengeTemplate(id: "coldshower30", name: L("Douche froide · 30 jours"),
                              summary: "Termine ta douche à l'eau froide pendant 30 jours.", icon: "snowflake",
                              color: Color(red: 0.40, green: 0.70, blue: 0.85), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "declutter30", name: L("Désencombrer · 30 jours"),
                              summary: "Jette ou donne un objet chaque jour, 30 jours.", icon: "shippingbox.fill",
                              color: Color(red: 0.72, green: 0.55, blue: 0.38), target: 30, unit: L("jours"), isDaily: true),
            ChallengeTemplate(id: "meditate100", name: L("100 minutes de méditation"),
                              summary: "Cumule 100 minutes de méditation. Suivi via Apple Santé.", icon: "brain.head.profile",
                              color: Color(red: 0.55, green: 0.45, blue: 0.80), target: 100, unit: L("min"), isDaily: false,
                              healthMetric: .mindful)
        ]
    }

    static func template(for id: String) -> ChallengeTemplate? {
        all.first { $0.id == id }
    }

    static func color(for id: String) -> Color {
        template(for: id)?.color ?? .accentDeep
    }
}
