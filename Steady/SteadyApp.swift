import SwiftUI
import SwiftData
import FirebaseCore

@main
struct SteadyApp: App {
    let container: ModelContainer

    init() {
        FirebaseApp.configure()
        NavBarAppearance.configure()
        NotificationActionHandler.shared.register()
        ReviewRequester.registerLaunch()
        let container = Self.makeContainer()
        self.container = container
        PhoneSyncService.shared.activate(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Color.accentDeep)
                .fontDesign(.rounded)
                // Consentement RGPD (UMP) puis démarrage AdMob + préchargement
                // de la pub récompensée. Ici (UI à l'écran) et non dans init() :
                // le formulaire de consentement a besoin d'un ViewController.
                .task { await AdConsentManager.requestConsentThenStartAds() }
        }
        .modelContainer(container)
    }

    /// Tente une base synchronisée via iCloud (CloudKit). En cas d'échec
    /// (pas de compte iCloud, hors-ligne au premier lancement…), on retombe
    /// sur une base purement locale pour ne jamais planter au démarrage.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Habit.self, DailyRecord.self, JournalEntry.self, Challenge.self, MoodEntry.self])

        // iCloud (CloudKit) DÉSACTIVÉ pour l'instant : il exige que TOUTES les
        // relations soient optionnelles (ex. `Habit.records`), ce qui demande un
        // refactor. La validation CloudKit plante sinon au démarrage sur un thread
        // de fond (non rattrapable). On reste donc sur une base 100 % locale.
        if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)) {
            return container
        }

        // Ancien store incompatible : on le réinitialise pour ne jamais bloquer le démarrage.
        deleteStoreFiles()
        if let container = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none)) {
            return container
        }

        // Dernier recours : en mémoire.
        return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
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

