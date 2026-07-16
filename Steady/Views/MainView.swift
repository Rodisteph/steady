import SwiftUI
import SwiftData
import StoreKit

/// Comment la liste d'habitudes est organisée sur l'écran principal.
enum HabitGroupMode: String, CaseIterable, Identifiable {
    case priority, category
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .priority: return "Importance"
        case .category: return "Catégorie"
        }
    }
    var icon: String {
        switch self {
        case .priority: return "exclamationmark.circle"
        case .category: return "square.grid.2x2"
        }
    }
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Query(sort: [SortDescriptor(\Habit.sortIndex), SortDescriptor(\Habit.creationDate)]) private var habits: [Habit]
    @Query(sort: \Exam.date) private var exams: [Exam]

    /// Prochain examen dans les 30 jours → bannière compte à rebours sur l'accueil.
    private var nextExam: Exam? {
        exams.first { !$0.isPast && $0.daysRemaining <= 30 }
    }

    var store: HabitStore

    @State private var showAddSheet = false
    @State private var showPremiumSheet = false
    @State private var showCelebration = false
    @State private var showReorderSheet = false
    @State private var showRoutines = false
    @State private var showChallenges = false
    @State private var showSocial = false
    @State private var showExams = false
    @State private var showWrappedDemo = false
    @State private var detailHabit: Habit?
    /// Habitude en attente de confirmation de suppression (l'historique part avec).
    @State private var habitToDelete: Habit?
    /// Heure courante — rafraîchie au retour au premier plan pour que la salutation
    /// (« Bonjour » / « Bonsoir ») ne reste pas figée sur le matin.
    @State private var now = Date()
    /// Message de confirmation éphémère (jour de repos, etc.).
    @State private var toast: String?
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

    /// Filtre par catégorie (bulles) — nil = tout afficher.
    @State private var categoryFilter: HabitCategory?

    /// Mode de regroupement de la liste (persisté).
    @AppStorage("steady_habit_group_mode") private var groupModeRaw = HabitGroupMode.priority.rawValue
    private var groupMode: HabitGroupMode { HabitGroupMode(rawValue: groupModeRaw) ?? .priority }

    /// Habitudes après filtre par bulle (avant regroupement/tri).
    private var filteredHabits: [Habit] {
        todaysHabits.filter { categoryFilter == nil || $0.category == categoryFilter }
    }

    /// Tri par importance : priorité haute d'abord, puis ordre manuel.
    private func byPriority(_ list: [Habit]) -> [Habit] {
        list.sorted {
            $0.priorityRaw == $1.priorityRaw
                ? $0.sortIndex < $1.sortIndex
                : $0.priorityRaw > $1.priorityRaw
        }
    }

    /// Liste à plat, triée par importance (mode « Importance » ou filtre actif).
    private var visibleHabits: [Habit] { byPriority(filteredHabits) }

    /// Regroupement par catégorie : sections dans l'ordre de l'enum, habitudes
    /// triées par importance à l'intérieur. Ne garde que les catégories non vides.
    private var groupedHabits: [(category: HabitCategory, habits: [Habit])] {
        HabitCategory.allCases.compactMap { category in
            let members = filteredHabits.filter { $0.category == category }
            return members.isEmpty ? nil : (category, byPriority(members))
        }
    }

    /// Combien de catégories différentes sont réellement utilisées aujourd'hui ?
    private var categoriesInUse: Int {
        Set(todaysHabits.map(\.categoryRaw)).count
    }

    var body: some View {
        NavigationStack {
            List {
                SteadyTitle("Steady")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                DailyProgressHeader(completed: completedToday, total: todaysHabits.count, now: now)
                    .plainRow()

                // (Le « Conseil du jour » vit désormais uniquement sur l'écran Coach —
                // évite le doublon sur l'accueil.)

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

                // Compte à rebours d'examen — le hook « étudiant » sur l'accueil.
                if let exam = nextExam {
                    examBanner(exam).plainRow()
                }

                // Vue d'ensemble par catégories : bulles proportionnelles, tap = filtre.
                CategoryBubblesView(habits: todaysHabits, selected: $categoryFilter)
                    .plainRow()

                // Sélecteur de tri : par importance (à plat) ou par catégorie (sections).
                // Masqué s'il n'y a qu'une catégorie ou un filtre actif (rien à regrouper).
                if categoryFilter == nil && categoriesInUse > 1 && todaysHabits.count > 1 {
                    organizeBar.plainRow()
                }

                if habits.isEmpty {
                    emptyState.plainRow()
                } else if todaysHabits.isEmpty {
                    nothingScheduledState.plainRow()
                } else if categoryFilter == nil && groupMode == .category {
                    // Regroupé par catégorie : un en-tête puis les habitudes.
                    ForEach(groupedHabits, id: \.category) { group in
                        categoryHeader(group.category, count: group.habits.count).plainRow()
                        ForEach(group.habits) { habit in
                            habitRow(habit, index: 0)
                        }
                    }
                } else {
                    // À plat, trié par importance.
                    ForEach(Array(visibleHabits.enumerated()), id: \.element.id) { index, habit in
                        habitRow(habit, index: index)
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
            .sheet(isPresented: $showExams) {
                ExamModeView(store: store)
            }
            .sheet(isPresented: $showWrappedDemo) {
                WrappedView(store: store, habits: Array(habits))
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
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Capsule().fill(Color.accentDeep))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: toast) {
                            // Disparaît tout seul après 2,5 s.
                            try? await Task.sleep(for: .seconds(2.5))
                            withAnimation { self.toast = nil }
                        }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast)
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
                if phase == .active {
                    store.applyPendingWidgetToggles()
                    now = Date()   // recalcule la salutation (matin/soir) au retour
                }
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
                if args.contains("-showExams") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showExams = true }
                }
                if args.contains("-showWrapped") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showWrappedDemo = true }
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
            quickAction("Examens", icon: "graduationcap.fill") { showExams = true }
            quickAction("Amis", icon: "person.2.fill") { showSocial = true }
        }
    }

    /// Bannière compte à rebours du prochain examen (tap → Exam Mode).
    private func examBanner(_ exam: Exam) -> some View {
        Button {
            showExams = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: exam.icon)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.2)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(exam.title).font(.subheadline.weight(.bold)).foregroundStyle(.white).lineLimit(1)
                    Text(exam.daysRemaining == 0 ? L("C'est aujourd'hui, courage !") : L("Plus que \(exam.daysRemaining) jours"))
                        .font(.caption).foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Text(exam.daysRemaining == 0 ? L("Jour J") : "J-\(exam.daysRemaining)")
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(exam.urgency == .critical ? AnyShapeStyle(LinearGradient(colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.30)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.accentGradient))
            )
        }
        .buttonStyle(.plain)
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

    /// Une carte d'habitude avec ses actions de balayage (partagée par les deux modes).
    @ViewBuilder
    private func habitRow(_ habit: Habit, index: Int) -> some View {
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
            // Pas de suppression directe : l'historique part avec, on confirme toujours.
            Button(role: .destructive) {
                habitToDelete = habit
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    /// Bascule entre « par importance » (liste à plat) et « par catégorie » (sections).
    private var organizeBar: some View {
        Picker("", selection: Binding(
            get: { groupMode },
            set: { newMode in withAnimation(.easeInOut(duration: 0.25)) { groupModeRaw = newMode.rawValue } }
        )) {
            ForEach(HabitGroupMode.allCases) { mode in
                Label(mode.title, systemImage: mode.icon).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    /// En-tête d'une section de catégorie : pastille colorée + nom + compteur.
    private func categoryHeader(_ category: HabitCategory, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(category.color))
            Text(category.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7).padding(.vertical, 1)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
            Spacer()
        }
        .padding(.top, Theme.Spacing.sm)
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
                Text("Au-delà de 3 habitudes, le suivi nécessite Premium. Tes habitudes et leur historique sont conservés : réactive-les quand tu veux.")
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
            HapticManager.success()
            // Confirmation visible : le bouton fait clairement quelque chose.
            toast = store.isRestDay
                ? L("Jour de repos activé 🌙 Tes séries sont protégées aujourd'hui.")
                : L("Jour de repos désactivé. Tes habitudes t'attendent 🌿")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.isRestDay ? "moon.zzz.fill" : "moon.zzz")
                Text(store.isRestDay ? "Repos actif" : "Jour de repos")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
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
    var now: Date = Date()

    private var progress: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
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
                Text(now, format: .dateTime.weekday(.wide).day().month(.wide).year())
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
