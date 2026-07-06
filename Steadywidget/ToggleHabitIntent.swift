import AppIntents
import WidgetKit

/// Intent déclenché en tapant une habitude dans le widget (iOS 17+).
/// Met à jour l'instantané immédiatement + met la validation en file pour l'app.
struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Valider une habitude"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}
    init(habitID: String) { self.habitID = habitID }

    func perform() async throws -> some IntentResult {
        SteadyWidgetStore.toggleInSnapshot(habitID)
        SteadyWidgetStore.queueToggle(habitID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
