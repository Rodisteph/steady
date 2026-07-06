import SwiftUI
import SwiftData
import StoreKit

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Query(sort: [SortDescriptor(\Habit.sortIndex), SortDescriptor(\Habit.creationDate)]) private var habits: [Habit]

    var store: HabitStore

    @State private var showAddSheet = false
    @State private var showPremiumSheet = false
    @State private var dailyInsight: CoachDailyInsight?
    @State private var showCelebration = false
    @State private var showReorderSheet = false
    @State private var showRoutines = false
    @State private var showChallenges = false
    @State private var showSocial = false
    @State private var detailHabit: Habit?
    /// Habitude en attente de confirmation de suppression (l'historique part avec).
    @State private var habitToDelete: Habit?
    /// Cascade jouée une seule fois (évite de re-fondre les lignes recyclées au scroll).
    @State private var staggerDone = false
    /// Travail de démarrage (notifications, Santé) fait une seule fois par lancement.
    @State private var didSetup = false
    @Namespace private var detailZoom

    private var isPremium: Bool { store.storeManager.isPremium }

    /// En gratuit, seules les 3 premières habitudes (dans l'ordre) restent actives.
    /// Les autres sont mises en pause (conservées) jusqu'au passage en Premium.
    private var activeHabits: [Habit] { isPremium ? habits : Array(habits.prefix(3)) }
    private var lockedHabits: [Habit] { isPremium ? [] : Array(habits.dropFirst(3)) }

    /// Habitudes prévues aujourd'hui (selon leur planning), parmi les actives.
    private var todaysHabits: [Habit] { activeHabits.filter { $0.isScheduled(on: Date()) } }
    private var completedToday: Int { store.completedTodayCount(among: todaysHabits) }

    var body: some View {
        NavigationStack {
            List {
                SteadyTitle("Steady")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                DailyProgressHeader(completed: completedToday, total: todaysHabits.count)
                    .plainRow()

                // Conseil du jour du coach (Premium) — la preuve quotidienne que l'app te connaît.
                if isPremium, let insight = dailyInsight {
                    DailyInsightCard(insight: insight)
                        .plainRow()
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Spacer(minLength: 0)
                    restDayButton
                    if store.storeManager.isPremium {
                        premiumBadge
                    }
                    Spacer(minLength: 0)
                }
                .plainRow()

                // Accès rapide : les grandes zones de l'app, visibles et étiquetées.
                quickActions
                    .plainRow()

                if habits.isEmpty {
                    emptyState.plainRow()
                } else if todaysHabits.isEmpty {
                    nothingScheduledState.plainRow()
                } else {
                    ForEach(Array(todaysHabits.enumerated()), id: \.element.id) { index, habit in
                        HabitCardView(habit: habit, store: store, onShowDetail: {
                            detailHabit = habit
                        }, onDelete: {
                            habitToDelete = habit
                        })
                        .matchedTransitionSource(id: habit.id, in: detailZoom)
                        .appearStagger(index, enabled: !staggerDone)
                        .plainRow()
                        .swipeActions(edge: .leading) {
                            Button {
                                detailHabit = habit
                            } label: {
                                Label("Détails", systemImage: "slider.horizontal.3")
                            }
                            .tint(Color.accentDeep)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // Pas de suppression directe : l'historique part avec,
                            // on demande toujours confirmation.
                            Button(role: .destructive) {
                                habitToDelete = habit
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }

                if !lockedHabits.isEmpty {
                    lockedHabitsBanner.plainRow()
                }
            }
            .listStyle(.plain)
            .listRowSpacing(Theme.Spacing.md)
            .scrollContentBackground(.hidden)
            .background(AnimatedBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPremiumSheet = true
                    } label: {
                        Image(systemName: store.storeManager.isPremium ? "crown.fill" : "crown")
                            .foregroundStyle(store.storeManager.isPremium ? Color.accentDeep : .secondary)
                    }
                    .accessibilityLabel(store.storeManager.isPremium ? "Premium actif" : "Passer à Premium")
                }

                if habits.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showReorderSheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Réorganiser les habitudes")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentDeep)
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
            .sheet(isPresented: $showReorderSheet) {
                ReorderHabitsView(store: store)
            }
            .sheet(isPresented: $showRoutines) {
                RoutineCategoryView(store: store) {
                    showRoutines = false
                }
            }
            .sheet(isPresented: $showChallenges) {
                NavigationStack { ChallengeView(store: store) }
            }
            .sheet(isPresented: $showSocial) {
                SocialHubView(myStreak: habits.map { store.currentStreak(for: $0) }.max() ?? 0)
            }
            .navigationDestination(item: $detailHabit) { habit in
                HabitDetailView(habit: habit, store: store)
                    .navigationTransition(.zoom(sourceID: habit.id, in: detailZoom))
            }
            .overlay {
                if showCelebration {
                    CelebrationView(isPresented: $showCelebration)
                }
            }
            .confirmationDialog(
                Text("Supprimer « \(habitToDelete?.name ?? "") » ?"),
                isPresented: Binding(
                    get: { habitToDelete != nil },
                    set: { if !$0 { habitToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Supprimer (historique inclus)", role: .destructive) {
                    if let habit = habitToDelete {
                        // Différé : laisse SwiftUI finir le retrait de la ligne
                        // avant de supprimer l'objet (évite le crash « detached data »).
                        DispatchQueue.main.async { store.deleteHabit(habit) }
                    }
                    habitToDelete = nil
                }
                Button("Annuler", role: .cancel) { habitToDelete = nil }
            } message: {
                Text("Ses validations et ses séries seront définitivement effacées.")
            }
            .onChange(of: completedToday) { oldValue, newValue in
                if !todaysHabits.isEmpty && newValue == todaysHabits.count && newValue > oldValue {
                    showCelebration = true
                    // Moment de joie → bon moment pour demander une note App Store
                    // (au plus tôt après 3 jours d'usage, une fois par version).
                    if ReviewRequester.shouldAsk() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { requestReview() }
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.applyPendingWidgetToggles() }
            }
            .onAppear {
                store.configure(with: modelContext)
                store.applyPendingWidgetToggles()
                // Travail lourd une seule fois par lancement (pas à chaque retour d'onglet).
                if !didSetup {
                    didSetup = true
                    store.refreshNotifications()
                    store.syncHealth()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { staggerDone = true }
                }
                if isPremium {
                    dailyInsight = DailyInsightEngine().today(habits: Array(habits), store: store)
                }
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-seedDemo") && habits.isEmpty {
                    store.seedDemoData()
                }
                if args.contains("-showPremium") {
                    showPremiumSheet = true
                }
                if args.contains("-showDetail") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        detailHabit = habits.first
                    }
                }
                if args.contains("-autoDemo") {
                    runAutoDemo()
                }
                #endif
            }
        }
    }

    #if DEBUG
    /// Scénario auto-joué pour le tournage vidéo (`-autoDemo`) — jamais en production.
    /// Décoche les habitudes du jour sans animation, puis les coche une à une
    /// avec les vraies animations (anneau, cartes, célébration finale).
    private func runAutoDemo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortIndex)])
            let all = (try? modelContext.fetch(descriptor)) ?? []
            let targets = all.filter { $0.isScheduled(on: Date()) }

            var noAnim = Transaction()
            noAnim.disablesAnimations = true
            withTransaction(noAnim) {
                for habit in targets where store.isCompleted(habit, on: Date()) {
                    store.toggleHabit(habit, on: Date())
                }
            }

            for (i, habit) in targets.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 + Double(i) * 1.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        store.toggleHabit(habit, on: Date())
                    }
                }
            }
        }
    }
    #endif

    // MARK: - Sous-vues

    /// Accès rapide étiqueté vers Routines / Défis / Communauté (fini les icônes cachées).
    private var quickActions: some View {
        HStack(spacing: Theme.Spacing.sm) {
            quickAction("Routines", icon: "square.stack.3d.up.fill") { showRoutines = true }
            quickAction("Défis", icon: "trophy.fill") { showChallenges = true }
            quickAction("Communauté", icon: "person.2.fill") { showSocial = true }
        }
    }

    private func quickAction(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentDeep)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .steadyCard(cornerRadius: Theme.Radius.md)
        }
        .buttonStyle(.plain)
    }

    private var lockedHabitsBanner: some View {
        Button {
            showPremiumSheet = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").foregroundStyle(Color.accentDeep)
                    Text("\(lockedHabits.count) habitude(s) en pause")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                Text("Au-delà de 3 habitudes, le suivi nécessite Premium. Tes habitudes et leur historique sont conservés — réactive-les quand tu veux.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                ForEach(lockedHabits) { habit in
                    HStack(spacing: 10) {
                        Image(systemName: habit.icon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.steadySurface))
                        Text(habit.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .strikethrough(false)
                        Spacer()
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Text("Réactiver avec Premium")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentGradient))
                    .padding(.top, 4)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .steadyCard()
        }
        .buttonStyle(.plain)
    }

    private var premiumBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
            Text("Premium")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.accentDeep)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.brandAccent.opacity(0.15)))
    }

    private var nothingScheduledState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentGradient)
            Text("Rien de prévu aujourd'hui")
                .font(.title3.weight(.bold))
            Text("Profites-en pour souffler. Tes habitudes t'attendent les jours prévus.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 40)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentGradient)
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
                    .background(Capsule().fill(Color.accentGradient))
            }
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 40)
    }

    /// Jour de repos : aujourd'hui ne compte pas — aucune série ne peut se casser.
    /// Valider reste possible (et ça compte quand même).
    private var restDayButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                store.isRestDay.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.isRestDay ? "moon.zzz.fill" : "moon.zzz")
                Text(store.isRestDay ? "Repos — séries protégées" : "Jour de repos")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(store.isRestDay ? .white : .secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(store.isRestDay ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadyCard))
            )
            .shadow(color: store.isRestDay ? Color.brandAccent.opacity(0.3) : Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .accessibilityLabel(store.isRestDay ? "Désactiver le jour de repos" : "Activer le jour de repos : tes séries ne peuvent pas se casser aujourd'hui")
    }
}

// MARK: - Style de ligne « carte » (List sans décor)

private extension View {
    /// Ligne de List transparente, sans séparateur, alignée sur les marges des cartes.
    func plainRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
        case 5..<12: return L("Bonjour")
        case 12..<18: return L("Bon après-midi")
        default: return L("Bonsoir")
        }
    }

    private var subtitle: String {
        if total == 0 { return L("Prêt à commencer ?") }
        if completed == total { return L("Tout est validé. Bravo !") }
        return L("\(completed) sur \(total) aujourd'hui")
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.title2.weight(.bold))
                Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentDeep)
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
                .stroke(Color.brandAccent.opacity(0.18), lineWidth: 8)

            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(Color.accentGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

            if total > 0 && completed == total {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.accentDeep)
                    .symbolEffect(.bounce, value: completed)
            } else {
                Text("\(completed)/\(total)")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completed)
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
