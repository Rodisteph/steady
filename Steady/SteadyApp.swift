import SwiftUI
import SwiftData
import FirebaseCore

@main
struct SteadyApp: App {
    let container: ModelContainer
    /// Relais UIKit pour le jeton APNs (notifications push des groupes).
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate

    init() {
        FirebaseApp.configure()
        NavBarAppearance.configure()
        NotificationActionHandler.shared.register()
        ReviewRequester.registerLaunch()
        let container = Self.makeContainer()
        self.container = container
        PhoneSyncService.shared.activate(container: container)
        PushNotificationService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Color.accentDeep)
                .fontDesign(.rounded)
                // Consentement RGPD (UMP) puis démarrage AdMob + préchargement
                // de la pub récompensée. Ici (UI à l'écran) et non dans init() :
                // le formulaire de consentement a besoin d'un ViewController.
                .task {
                    // En mode démo/capture d'écran, on n'affiche pas le formulaire de
                    // consentement pub (il masquerait l'UI). Comportement normal ailleurs.
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-seedDemo") { return }
                    #endif
                    await AdConsentManager.requestConsentThenStartAds()
                }
        }
        .modelContainer(container)
    }

    /// Base synchronisée via iCloud (CloudKit) : les habitudes, l'historique, le
    /// journal, les défis et les humeurs sont sauvegardés dans l'iCloud privé de
    /// l'utilisateur → restaurés après réinstallation ET synchronisés entre appareils.
    /// Prérequis (remplis) : toutes les relations to-many sont optionnelles
    /// (`Habit.recordsStore`) et tous les attributs ont une valeur par défaut.
    /// En cas d'échec (pas de compte iCloud, hors-ligne…), repli sur une base locale.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Habit.self, DailyRecord.self, JournalEntry.self, Challenge.self, MoodEntry.self, Exam.self])

        // 1) iCloud (CloudKit) — l'objectif : plus jamais de perte de données.
        if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)) {
            recordStorageMode("icloud")
            return container
        }

        // 2) Repli local (pas de compte iCloud, etc.) — l'app fonctionne quand même.
        if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)) {
            recordStorageMode("local")
            return container
        }

        // 3) Ancien store incompatible : on le réinitialise pour ne jamais bloquer.
        deleteStoreFiles()
        if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)) {
            recordStorageMode("local")
            return container
        }

        // 4) Dernier recours : en mémoire.
        recordStorageMode("memory")
        return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }

    /// Mémorise le mode de stockage réellement actif, pour l'afficher dans les
    /// Réglages. Un repli silencieux sur « local » = pas de restauration après
    /// réinstallation → l'utilisateur doit pouvoir le voir.
    private static func recordStorageMode(_ mode: String) {
        UserDefaults.standard.set(mode, forKey: "steady_storage_mode")
        print("💾 Stockage Steady : \(mode)")
    }

    /// Supprime le fichier de base SwiftData par défaut (et ses annexes WAL/SHM).
    private static func deleteStoreFiles() {
        let fm = FileManager.default
        guard let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return }
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? fm.removeItem(at: support.appendingPathComponent(name))
        }
    }
}

