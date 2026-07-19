import SwiftUI
import Observation

/// Mémoire du coach (100 % sur l'appareil) : elle apprend de ce à quoi tu réagis.
///
/// - **Anti-répétition** : chaque type de conseil (`tag`) a une date de dernière
///   apparition ; un conseil montré récemment est fortement dé-priorisé.
/// - **Apprentissage** : le 👍 / 👎 sur le conseil du jour ajuste le poids de son
///   `tag`, ce qui remonte ou fait descendre ce type de conseil à l'avenir.
/// - **Stabilité** : le conseil du jour est figé pour la journée (il ne change
///   pas à chaque ouverture de l'écran).
///
/// Rien ne quitte l'appareil : tout vit dans `UserDefaults`.
@MainActor
@Observable
final class CoachMemory {
    static let shared = CoachMemory()

    private let defaults = UserDefaults.standard
    private let weightsKey = "coach_tag_weights"
    private let shownKey = "coach_tag_lastshown"
    private let todayTagKey = "coach_today_tag"
    private let todayDateKey = "coach_today_date"

    private(set) var weights: [String: Double]
    private var lastShown: [String: Date]

    private init() {
        weights = (defaults.dictionary(forKey: weightsKey) as? [String: Double]) ?? [:]
        lastShown = (defaults.dictionary(forKey: shownKey) as? [String: Date]) ?? [:]
    }

    // MARK: - Lecture

    /// Poids appris d'un type de conseil (1 = neutre, <1 = évité, >1 = favorisé).
    func weight(_ tag: String) -> Double { weights[tag] ?? 1.0 }

    /// Jours depuis la dernière apparition de ce type (nil = jamais montré).
    func daysSinceShown(_ tag: String) -> Int? {
        guard let date = lastShown[tag] else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }

    // MARK: - Choix du jour (figé sur la journée)

    /// Le tag déjà choisi aujourd'hui, s'il existe.
    func todayTag() -> String? {
        guard let date = defaults.object(forKey: todayDateKey) as? Date,
              Calendar.current.isDateInToday(date) else { return nil }
        return defaults.string(forKey: todayTagKey)
    }

    /// Fige le conseil du jour et note son apparition (anti-répétition).
    func setTodayTag(_ tag: String) {
        defaults.set(tag, forKey: todayTagKey)
        defaults.set(Date(), forKey: todayDateKey)
        lastShown[tag] = Date()
        defaults.set(lastShown, forKey: shownKey)
    }

    // MARK: - Apprentissage

    /// A-t-on déjà un avis sur le conseil du jour ? (pour figer les boutons 👍/👎)
    var todayFeedbackGiven: Bool {
        guard let date = defaults.object(forKey: "coach_today_feedback_date") as? Date,
              Calendar.current.isDateInToday(date) else { return false }
        return true
    }

    /// 👍 / 👎 sur un type de conseil : ajuste son poids (borné 0,3 … 2,0).
    func reinforce(_ tag: String, helpful: Bool) {
        let current = weights[tag] ?? 1.0
        weights[tag] = helpful ? min(2.0, current + 0.35) : max(0.3, current - 0.4)
        defaults.set(weights, forKey: weightsKey)
        defaults.set(Date(), forKey: "coach_today_feedback_date")
        HapticManager.lightImpact()
    }
}
