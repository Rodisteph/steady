import SwiftUI
import SwiftData

@main
struct SteadyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color.steadySageDeep)
                .fontDesign(.rounded)
        }
        .modelContainer(for: [Habit.self, DailyRecord.self])
    }
}

