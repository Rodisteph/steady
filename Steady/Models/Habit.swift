import SwiftData
import Foundation

@Model
final class Habit {
    // Pas de contrainte .unique : incompatible avec la synchro CloudKit.
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "star.fill"
    var colorHex: String = "#8DA399"
    var creationDate: Date = Date()
    /// Position manuelle (glisser-déposer). Plus petit = plus haut.
    var sortIndex: Int = 0

    /// Rappel propre à cette habitude.
    var reminderEnabled: Bool = false
    /// Heure du rappel (seules l'heure et la minute sont utilisées).
    var reminderTime: Date?

    /// Jours de la semaine où l'habitude est prévue (1=dimanche … 7=samedi, façon `Calendar`).
    /// Vide = tous les jours.
    var scheduledWeekdays: [Int] = []

    /// Objectif quotidien. 1 = habitude simple (oui/non). > 1 = habitude chiffrée (compteur).
    var dailyGoal: Int = 1
    /// Unité affichée pour une habitude chiffrée (ex. « verres », « min »). Optionnel.
    var unit: String = ""

    /// Métrique Apple Santé liée (vide = aucune). Permet l'auto-validation.
    var healthMetricRaw: String = ""
    var healthMetric: HealthMetric? { HealthMetric(rawValue: healthMetricRaw) }

    /// Catégorie (« genre ») — brute pour SwiftData, vide = Autre.
    var categoryRaw: String = ""
    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Priorité : 2 = haute, 1 = normale (défaut), 0 = basse.
    var priorityRaw: Int = 1
    var priority: HabitPriority {
        get { HabitPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    /// Habitude chiffrée (avec compteur) ?
    var isCounter: Bool { dailyGoal > 1 }

    /// Stockage réel de la relation. CloudKit EXIGE que les relations to-many
    /// soient optionnelles (sinon crash à l'init du conteneur, non rattrapable).
    /// On garde ce champ privé et on expose `records` non-optionnel juste en dessous
    /// → les 41 usages existants ne changent pas.
    @Relationship(deleteRule: .cascade, inverse: \DailyRecord.habit)
    var recordsStore: [DailyRecord]?

    /// Accès pratique et non-optionnel à l'historique (lecture seule).
    var records: [DailyRecord] { recordsStore ?? [] }

    /// L'habitude est-elle prévue ce jour-là ? (vide = tous les jours)
    func isScheduled(on date: Date) -> Bool {
        guard !scheduledWeekdays.isEmpty else { return true }
        let weekday = Calendar.current.component(.weekday, from: date)
        return scheduledWeekdays.contains(weekday)
    }

    init(name: String, icon: String, colorHex: String = "#8DA399", sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.creationDate = Date()
        self.sortIndex = sortIndex
    }
}
