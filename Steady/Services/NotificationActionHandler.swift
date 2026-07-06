import Foundation
import UserNotifications
import WidgetKit

/// Gère le bouton « Valider » directement dans les notifications de rappel.
/// Réutilise la file d'attente du widget (App Group) : l'app applique la
/// validation à SwiftData à sa prochaine ouverture — zéro duplication de logique.
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    static let completeActionID = "steady_complete_action"
    static let habitCategoryID = "steady_habit_reminder"

    /// À appeler au démarrage : enregistre la catégorie avec le bouton « Valider ».
    func register() {
        let complete = UNNotificationAction(
            identifier: Self.completeActionID,
            title: L("Valider ✓"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.habitCategoryID,
            actions: [complete],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

    // Le bouton « Valider » a été touché.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        guard response.actionIdentifier == Self.completeActionID,
              let habitID = response.notification.request.content.userInfo["habit_id"] as? String
        else { return }

        // Retour visuel immédiat (widget) + mise en file pour SwiftData.
        SteadyWidgetStore.toggleInSnapshot(habitID)
        SteadyWidgetStore.queueToggle(habitID)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Afficher la notification même si l'app est au premier plan.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
