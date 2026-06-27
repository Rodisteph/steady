import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.creationDate) private var habits: [Habit]

    var store: HabitStore

    @State private var showAddSheet = false
    @State private var showPremiumSheet = false

    private var completedToday: Int { store.completedTodayCount(among: habits) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    DailyProgressHeader(completed: completedToday, total: habits.count)
                        .padding(.horizontal)
                        .padding(.top, Theme.Spacing.sm)

                    HStack(spacing: Theme.Spacing.sm) {
                        restDayButton
                        if store.storeManager.isPremium {
                            premiumBadge
                        }
                    }

                    if habits.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(habits) { habit in
                                HabitCardView(habit: habit, store: store)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color.steadyBackground.ignoresSafeArea())
            .navigationTitle("Steady")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPremiumSheet = true
                    } label: {
                        Image(systemName: store.storeManager.isPremium ? "crown.fill" : "crown")
                            .foregroundStyle(store.storeManager.isPremium ? Color.steadySageDeep : .secondary)
                    }
                    .accessibilityLabel(store.storeManager.isPremium ? "Premium actif" : "Passer à Premium")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.steadySageDeep)
                    }
                    .accessibilityLabel("Ajouter une habitude")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddHabitView(store: store, currentCount: habits.count)
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView(storeManager: store.storeManager)
            }
            .onAppear {
                store.configure(with: modelContext)
                store.refreshNotifications()
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-seedDemo") && habits.isEmpty {
                    store.seedDemoData()
                }
                if args.contains("-showPremium") {
                    showPremiumSheet = true
                }
                #endif
            }
        }
    }

    // MARK: - Sous-vues

    private var premiumBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
            Text("Premium")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.steadySageDeep)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.steadySage.opacity(0.15)))
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.steadySageGradient)
            Text("Commencez en douceur")
                .font(.title3.weight(.bold))
            Text("Ajoutez une première habitude et avancez à votre rythme, un jour à la fois.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showAddSheet = true
            } label: {
                Label("Ajouter une habitude", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.steadySageGradient))
            }
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 40)
    }

    private var restDayButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                store.isRestDay.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.isRestDay ? "moon.fill" : "moon")
                Text(store.isRestDay ? "Bienveillance active" : "Mode Bienveillance")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(store.isRestDay ? .white : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(store.isRestDay ? AnyShapeStyle(Color.steadySageGradient) : AnyShapeStyle(Color.steadyCard))
            )
            .shadow(color: store.isRestDay ? Color.steadySage.opacity(0.3) : Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .accessibilityLabel(store.isRestDay ? "Désactiver le mode bienveillance" : "Activer le mode bienveillance")
    }
}

// MARK: - Header avec anneau de progression

struct DailyProgressHeader: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bonjour"
        case 12..<18: return "Bon après-midi"
        default: return "Bonsoir"
        }
    }

    private var subtitle: String {
        if total == 0 { return "Prêt à commencer ?" }
        if completed == total { return "Tout est validé. Bravo !" }
        return "\(completed) sur \(total) aujourd'hui"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.title2.weight(.bold))
                Text(Date().formatted(date: .complete, time: .omitted).capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.steadySageDeep)
                    .padding(.top, 2)
            }

            Spacer()

            ProgressRing(progress: progress, completed: completed, total: total)
        }
        .padding(Theme.Spacing.lg)
        .steadyCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting). \(subtitle).")
    }
}

struct ProgressRing: View {
    let progress: Double
    let completed: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.steadySage.opacity(0.18), lineWidth: 8)

            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(Color.steadySageGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

            if total > 0 && completed == total {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.steadySageDeep)
            } else {
                Text("\(completed)/\(total)")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 64, height: 64)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, DailyRecord.self, configurations: config)
    return MainView(store: HabitStore())
        .modelContainer(container)
}
