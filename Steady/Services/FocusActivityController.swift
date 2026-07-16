import ActivityKit
import Foundation

/// Pilote la Live Activity du minuteur de révision : écran verrouillé et
/// Dynamic Island, pour suivre sa session sans rouvrir l'app.
///
/// Aucune mise à jour périodique n'est envoyée : on donne la date de fin une
/// fois, et `Text(timerInterval:)` fait le décompte côté système.
@MainActor
enum FocusActivityController {

    private static var current: Activity<FocusActivityAttributes>?

    /// L'utilisateur a-t-il autorisé les Live Activities ? (réglable dans iOS)
    static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Démarre le minuteur sur l'écran verrouillé.
    static func start(examTitle: String, startDate: Date, endDate: Date) {
        guard isAvailable else { return }
        endAll()   // jamais deux minuteurs affichés en même temps

        let attributes = FocusActivityAttributes(examTitle: examTitle, startDate: startDate)
        let state = FocusActivityAttributes.ContentState(endDate: endDate)
        current = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: endDate),
            pushType: nil          // tout est local, aucun serveur impliqué
        )
    }

    /// Retire le minuteur (session terminée, arrêtée, ou app relancée).
    static func endAll() {
        current = nil
        // La boucle est DANS la tâche : lancer une tâche par activité ferait
        // sortir chaque `activity` du main actor (risque de course signalé
        // par le compilateur).
        Task { @MainActor in
            // On balaie TOUTES les activités : si l'app a été tuée pendant une
            // session, une activité fantôme peut survivre à `current`.
            for activity in Activity<FocusActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
