import Foundation
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

/// Notifications push des groupes.
///
/// Approche : on publie le **jeton APNs BRUT** (hex) dans `users/{uid}.apnsToken`.
/// La Cloud Function `notifyGroupMessage` envoie ensuite directement à Apple (APNs),
/// en essayant l'environnement sandbox PUIS production. Ça marche donc que le jeton
/// soit de dev (sandbox) ou de prod (TestFlight/App Store) — sans jamais deviner,
/// ce qui évite l'erreur `BadEnvironmentKeyInToken`.
@MainActor
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()

    /// À appeler au lancement (après `FirebaseApp.configure()`).
    func activate() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// À appeler à l'ouverture de la Communauté (connecté) : demande l'autorisation
    /// d'AFFICHER les notifications — sans elle, les push arrivent mais restent
    /// invisibles — puis (ré)enregistre le push et publie le jeton APNs.
    func requestPermissionAndSync() {
        guard Auth.auth().currentUser != nil else { return }
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            UIApplication.shared.registerForRemoteNotifications()
            publishAPNSToken()
        }
    }

    /// Compat : appelé ailleurs dans le code — publie le jeton APNs.
    func syncTokenToProfile() { publishAPNSToken() }

    /// Jeton APNs reçu par l'AppDelegate : on le garde en hex et on le publie.
    func setAPNSToken(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: "steady_apns_token")
        publishAPNSToken()
    }

    /// Écrit le jeton APNs brut dans mon profil (si connecté).
    private func publishAPNSToken() {
        guard let uid = Auth.auth().currentUser?.uid,
              let hex = UserDefaults.standard.string(forKey: "steady_apns_token") else { return }
        Firestore.firestore().collection("users").document(uid)
            .setData(["apnsToken": hex], merge: true)
    }
}

/// Relais UIKit minimal : reçoit le jeton APNs du système.
final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushNotificationService.shared.setAPNSToken(deviceToken) }
    }
}
