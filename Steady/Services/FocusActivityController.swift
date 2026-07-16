import ActivityKit
import Foundation

/// Pilote la Live Activity du minuteur de révision : écran verrouillé et
/// Dynamic Island, pour suivre sa session sans rouvrir l'app.
///
/// Aucune mise à jour périodique n'est envoyée : on donne la date de fin une
/// fois, et `Text(timerInterval:)` fait le décompte côté système.
///
/// Tout est `async` et reste sur le main actor : c'est ce qui permet de finir
/// les anciennes activités AVANT de demander la nouvelle, sans faire traverser
/// de frontière d'acteur aux `Activity` (qui ne sont pas `Sendable`).
@MainActor
enum FocusActivityController {

    private static var current: Activity<FocusActivityAttributes>?

    /// L'utilisateur a-t-il autorisé les Live Activities ? (réglable dans iOS)
    static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Démarre le minuteur sur l'écran verrouillé.
    static func start(examTitle: String, startDate: Date, endDate: Date) async {
        guard isAvailable else {
            print("⚠️ Live Activity : désactivée dans Réglages > Steady > Activités en direct")
            return
        }
        // On attend vraiment la fin des anciennes : sinon elles seraient
        // supprimées après la création de la nouvelle… qui disparaîtrait avec.
        await endAll()

        let attributes = FocusActivityAttributes(examTitle: examTitle, startDate: startDate)
        let state = FocusActivityAttributes.ContentState(endDate: endDate)
        do {
            // Surtout pas `try?` ici : un échec silencieux rend le minuteur
            // invisible sans le moindre indice sur la cause.
            current = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endDate),
                pushType: nil          // tout est local, aucun serveur impliqué
            )
            print("✅ Live Activity démarrée jusqu'à \(endDate)")
        } catch {
            print("⚠️ Live Activity refusée : \(error.localizedDescription)")
        }
    }

    /// Retire le minuteur (session terminée, arrêtée, ou app relancée).
    ///
    /// On balaie TOUTES les activités et pas seulement `current` : si l'app a
    /// été tuée pendant une session, une activité fantôme lui survit.
    static func endAll() async {
        current = nil
        for activity in Activity<FocusActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
