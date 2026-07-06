import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let habit: Habit
    var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var icon: String = ""
    @State private var showDeleteConfirm = false
    @State private var reminderOn = false
    @State private var reminderTime = Date()
    @State private var selectedWeekdays: Set<Int> = []
    @State private var goal = 1
    @State private var unit = ""
    @State private var healthMetric: HealthMetric?
    @State private var showIconPicker = false
    @State private var showPremium = false
    @State private var healthToday: Double?

    private var isPremium: Bool { store.storeManager.isPremium }

    /// Ordre d'affichage Lun→Dim (numéros Calendar : Dim=1 … Sam=7).
    private let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var hasChanges: Bool {
        !trimmedName.isEmpty &&
        (trimmedName != habit.name || icon != habit.icon || goal != habit.dailyGoal || unit != habit.unit)
    }

    var body: some View {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    hero
                    statsGrid
                    if store.canRepairYesterday(for: habit) {
                        repairCard
                    }
                    scheduleCard
                    reminderCard
                    healthCard
                    historyCard
                    editCard
                    deleteButton
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Détail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear {
                name = habit.name
                icon = habit.icon
                reminderOn = habit.reminderEnabled
                reminderTime = habit.reminderTime ?? Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
                selectedWeekdays = Set(habit.scheduledWeekdays)
                goal = habit.dailyGoal
                unit = habit.unit
                healthMetric = habit.healthMetric
            }
            .sheet(isPresented: $showPremium) {
                PremiumView(storeManager: store.storeManager)
            }
            .confirmationDialog("Supprimer cette habitude ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    // On ferme d'abord, puis on supprime (évite d'accéder à l'objet supprimé).
                    dismiss()
                    DispatchQueue.main.async { store.deleteHabit(habit) }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Tout l'historique de cette habitude sera supprimé.")
            }
    }

    // MARK: - Réparation de série

    /// Série cassée hier → on peut la réparer en dépensant des pièces.
    /// Répare la journée entière (jour de repos rétroactif pour toutes les habitudes).
    private var repairCard: some View {
        let game = GamificationManager.shared
        let lost = store.streakBeforeYesterday(for: habit)
        let cost = HabitStore.repairCost
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Ta série s'est arrêtée hier", systemImage: "flame.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.steadyFlame)
            Text("Tu avais \(lost) jours d'affilée. Protège la journée d'hier pour la faire repartir — elle comptera comme un jour de repos.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                if GamificationManager.shared.spend(coins: cost) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        store.repairYesterday()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.circle.fill")
                    Text("Réparer ma série · \(cost) pièces")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(game.coins >= cost ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.secondary.opacity(0.3))))
            }
            .buttonStyle(.plain)
            .disabled(game.coins < cost)

            if game.coins < cost {
                Text("Il te manque \(cost - game.coins) pièces. Valide tes habitudes pour en gagner (+5 par validation).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Color.steadyFlame.opacity(0.10))
        )
    }

    // MARK: - Sous-vues

    private var hero: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: habit.icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(Circle().fill(Color.accentGradient))
                .shadow(color: Color.brandAccent.opacity(0.35), radius: 12, y: 6)
            Text(habit.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private var statsGrid: some View {
        let current = store.currentStreak(for: habit)
        let best = store.longestStreak(for: habit)
        let month = habit.records.filter { isInCurrentMonth($0.date) && $0.count >= habit.dailyGoal }.count
        let total = store.totalCompletions(for: habit)

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md), GridItem(.flexible())], spacing: Theme.Spacing.md) {
            DetailStat(value: "\(current)", label: "Série actuelle", icon: "flame.fill", tint: .steadyFlame)
            DetailStat(value: "\(best)", label: "Record", icon: "trophy.fill", tint: .accentDeep)
            DetailStat(value: "\(month)", label: "Ce mois-ci", icon: "calendar", tint: .accentDeep)
            DetailStat(value: "\(total)", label: "Total", icon: "checkmark.circle.fill", tint: .accentDeep)
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label("Fréquence", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(selectedWeekdays.isEmpty ? "Tous les jours" : "\(selectedWeekdays.count) j/sem")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(weekdayOrder, id: \.self) { wd in
                    let on = selectedWeekdays.isEmpty || selectedWeekdays.contains(wd)
                    Button {
                        toggleWeekday(wd)
                    } label: {
                        Text(weekdaySymbol(wd))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(on ? .white : .secondary)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle().fill(on ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadySurface))
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }

    private func weekdaySymbol(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return symbols[(weekday - 1) % symbols.count].uppercased()
    }

    private func toggleWeekday(_ wd: Int) {
        var set = selectedWeekdays.isEmpty ? Set(1...7) : selectedWeekdays
        if set.contains(wd) {
            if set.count == 1 { return }   // garder au moins un jour prévu
            set.remove(wd)
        } else {
            set.insert(wd)
        }
        if set.count == 7 { set = [] }     // toute la semaine = « tous les jours »
        selectedWeekdays = set
        store.setSchedule(for: habit, weekdays: Array(set))
        HapticManager.lightImpact()
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Toggle(isOn: $reminderOn) {
                Label("Me rappeler cette habitude", systemImage: "bell.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Color.accentDeep)

            if reminderOn {
                Divider()
                DatePicker("Heure du rappel", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .font(.subheadline)

                if let hour = store.suggestedReminderHour(for: habit) {
                    Button {
                        if let suggested = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
                            reminderTime = suggested
                        }
                        HapticManager.lightImpact()
                    } label: {
                        Label("Suggéré d'après tes validations : \(hour)h", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentDeep)
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .onChange(of: reminderOn) { _, on in
            if on {
                // Active les notifications globales si besoin (demande l'autorisation).
                NotificationManager.shared.isEnabled = true
            }
            store.setReminder(for: habit, enabled: on, time: reminderTime)
        }
        .onChange(of: reminderTime) { _, newTime in
            if reminderOn {
                store.setReminder(for: habit, enabled: true, time: newTime)
            }
        }
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label { Text("Apple Santé") } icon: { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isPremium {
                    Picker("", selection: $healthMetric) {
                        Text("Aucune").tag(HealthMetric?.none)
                        ForEach(HealthMetric.allCases) { metric in
                            Text(metric.title).tag(HealthMetric?.some(metric))
                        }
                    }
                    .labelsHidden()
                    .tint(Color.accentDeep)
                } else {
                    Button {
                        showPremium = true
                    } label: {
                        Label("Premium", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentDeep)
                    }
                }
            }
            if isPremium, let metric = healthMetric {
                let target = metric.target(forGoal: goal)
                let value = healthToday ?? 0
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Aujourd'hui")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(value)) / \(Int(target)) \(healthUnit(metric))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(value >= target ? .green : Color.accentDeep)
                            .contentTransition(.numericText())
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.brandAccent.opacity(0.15))
                            Capsule().fill(value >= target ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.accentGradient))
                                .frame(width: max(6, geo.size.width * min(1, target > 0 ? value / target : 0)))
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.vertical, 2)

                Text("Quand cette donnée Santé atteint le seuil dans la journée, l'habitude se valide toute seule. Tu peux aussi la cocher à la main.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Lie cette habitude à l'app Santé (eau, méditation ou pas) : elle se validera automatiquement quand ton objectif du jour est atteint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .task(id: healthMetric) { await refreshHealthToday() }
        .onChange(of: goal) { _, _ in Task { await refreshHealthToday() } }
        .onChange(of: healthMetric) { _, metric in
            store.setHealthMetric(for: habit, metric: metric)
            if metric != nil {
                Task {
                    await HealthManager.shared.requestAuthorization()
                    await refreshHealthToday()
                    store.syncHealth()
                }
            }
        }
    }

    /// Unité lisible pour chaque métrique Santé.
    private func healthUnit(_ metric: HealthMetric) -> String {
        switch metric {
        case .water: return L("verres")
        case .mindful: return L("min")
        case .steps: return L("pas")
        }
    }

    /// Lit la valeur Santé du jour pour afficher la progression.
    private func refreshHealthToday() async {
        guard isPremium, let metric = healthMetric else { healthToday = nil; return }
        healthToday = await HealthManager.shared.todayValue(for: metric)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Historique")
                    .font(.headline)
                Spacer()
                Text(Date(), format: .dateTime.month(.wide).year())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentDeep)
            }
            HabitMonthGrid(completedDays: completedDaysThisMonth()) { day in
                store.toggleCompletion(habit, on: day)
            }

            Text("Tape un jour pour le cocher ou le décocher.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }

    private var editCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Modifier".uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Nom de l'habitude", text: $name)
                .padding(Theme.Spacing.md)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Color.steadyCard))

            Button {
                showIconPicker = true
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.accentGradient))
                    Text("Choisir une icône")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.md)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Color.steadyCard))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selection: $icon)
            }

            Divider()

            Stepper(value: $goal, in: 1...50) {
                HStack {
                    Label { Text("Objectif par jour") } icon: { Image(systemName: "target").foregroundStyle(Color.accentDeep) }
                    Spacer()
                    Text(goal == 1 ? "Simple" : "\(goal)\(unit.isEmpty ? "" : " \(unit)")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color.accentDeep)

            if goal > 1 {
                TextField("Unité (ex. verres, min, pages)", text: $unit)
                    .autocorrectionDisabled()
                    .padding(Theme.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Color.steadySurface))
            }

            Text("Tes modifications sont enregistrées automatiquement.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        // Sauvegarde instantanée : cohérent avec fréquence/rappel/Santé (rien à « valider »).
        .onChange(of: name) { _, _ in saveEdits() }
        .onChange(of: icon) { _, _ in saveEdits() }
        .onChange(of: goal) { _, _ in saveEdits() }
        .onChange(of: unit) { _, _ in saveEdits() }
    }

    /// Enregistre nom/icône/objectif dès qu'ils changent (nom vide ignoré).
    private func saveEdits() {
        let newName = trimmedName.isEmpty ? habit.name : trimmedName
        store.updateHabit(habit, name: newName, icon: icon)
        store.setGoal(for: habit, goal: goal, unit: unit)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Supprimer l'habitude", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Color.red.opacity(0.12)))
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helpers

    private func isInCurrentMonth(_ date: Date) -> Bool {
        Calendar.current.dateInterval(of: .month, for: Date())?.contains(date) ?? false
    }

    private func completedDaysThisMonth() -> Set<Date> {
        let cal = Calendar.current
        return Set(habit.records
            .filter { $0.count >= habit.dailyGoal && isInCurrentMonth($0.date) }
            .map { cal.startOfDay(for: $0.date) })
    }
}

// MARK: - Tuile de stat (détail)

private struct DetailStat: View {
    let value: String
    let label: LocalizedStringKey
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .steadyCard(cornerRadius: Theme.Radius.md)
    }
}

// MARK: - Grille calendrier (1 habitude, mois courant)

private struct HabitMonthGrid: View {
    let completedDays: Set<Date>
    var onToggle: (Date) -> Void = { _ in }
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(weekdaySymbols(), id: \.self) { s in
                    Text(s).font(.caption2.weight(.medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<leadingEmptyCount(), id: \.self) { _ in Color.clear.frame(height: 30) }
                ForEach(monthDays(), id: \.self) { day in
                    let start = calendar.startOfDay(for: day)
                    let done = completedDays.contains(start)
                    let isFuture = start > calendar.startOfDay(for: Date())
                    let isToday = calendar.isDateInToday(day)

                    Button {
                        onToggle(day)
                    } label: {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(done ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadySurface))
                            .frame(height: 30)
                            .overlay {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(done ? .white : (isFuture ? Color.secondary.opacity(0.3) : .secondary))
                            }
                            .overlay {
                                if isToday && !done {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.accentDeep, lineWidth: 1.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
                }
            }
        }
    }

    private func monthDays() -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: Date()),
              let range = calendar.range(of: .day, in: .month, for: Date()) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
    }
    private func leadingEmptyCount() -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return 0 }
        let weekday = calendar.component(.weekday, from: interval.start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    private func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(first + $0) % symbols.count] }
    }
}
