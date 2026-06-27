import SwiftUI

struct ContentView: View {
    @State private var selectedTab = ContentView.initialTab
    @State private var store = HabitStore()

    /// Onglet initial — pilotable par `-tab N` pour les captures d'écran.
    private static var initialTab: Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let n = Int(args[i + 1]) {
            return n
        }
        return 0
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MainView(store: store)
                .tabItem {
                    Label("Habitudes", systemImage: "checkmark.circle")
                }
                .tag(0)
            
            WeeklySummaryView(store: store)
                .tabItem {
                    Label("Résumé", systemImage: "chart.bar")
                }
                .tag(1)
            
            SettingsView(store: store)
                .tabItem {
                    Label("Paramètres", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(Color.steadySageDeep)
    }
}



#Preview {
    ContentView()
}
