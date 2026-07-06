import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = ContentView.initialTab
    @State private var store = HabitStore()
    private var localization = LocalizationManager.shared
    private var theme = ThemeManager.shared

    @AppStorage("steady_has_onboarded") private var hasOnboarded = false
    /// Paywall de bienvenue : montré UNE fois, juste après l'onboarding (pic de motivation).
    @AppStorage("steady_onboarding_paywall_seen") private var onboardingPaywallSeen = false
    @State private var showOnboardingPaywall = false

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

            CoachScreen(store: store)
                .tabItem {
                    Label("Coach", systemImage: "sparkles")
                }
                .tag(1)

            WeeklySummaryView(store: store)
                .tabItem {
                    Label("Progrès", systemImage: "chart.bar")
                }
                .tag(2)

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book.closed")
                }
                .tag(3)

            SettingsView(store: store)
                .tabItem {
                    Label("Paramètres", systemImage: "gear")
                }
                .tag(4)
        }
        .tint(Color.accentDeep)
        .environment(\.locale, localization.locale)
        .id("\(localization.language.rawValue)-\(theme.palette.rawValue)")
        .sheet(isPresented: $showOnboardingPaywall) {
            PremiumView(storeManager: store.storeManager)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasOnboarded && !ProcessInfo.processInfo.arguments.contains("-skipOnboarding") },
            set: { _ in }
        )) {
            OnboardingView { profile in
                if let profile {
                    store.configure(with: modelContext)
                    store.seedProfile(profile)
                }
                withAnimation { hasOnboarded = true }
                // L'offre d'essai, une seule fois, au moment où la motivation est maximale.
                if !onboardingPaywallSeen {
                    onboardingPaywallSeen = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        showOnboardingPaywall = true
                    }
                }
            }
            .environment(\.locale, localization.locale)
        }
    }
}



#Preview {
    ContentView()
}
