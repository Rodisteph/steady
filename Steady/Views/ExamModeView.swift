import SwiftUI
import SwiftData

/// « Exam Mode » : la fonctionnalité qui parle vraiment aux étudiants.
/// Compte à rebours des partiels, focus révision (Pomodoro) et allègement des
/// habitudes pendant le rush (les séries ne se cassent pas en période d'examens).
struct ExamModeView: View {
    var store: HabitStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exam.date) private var exams: [Exam]

    @State private var showAdd = false
    @State private var showPremium = false
    @State private var focusExam: Exam?

    private var isPremium: Bool { store.storeManager.isPremium }

    /// Examens à venir (aujourd'hui ou futur), les plus proches d'abord.
    private var upcoming: [Exam] { exams.filter { !$0.isPast } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header

                    if upcoming.isEmpty {
                        emptyState
                    } else {
                        // Le prochain examen en grand (compte à rebours héros).
                        if let next = upcoming.first {
                            heroCountdown(next)
                        }
                        // Les suivants en liste compacte.
                        if upcoming.count > 1 {
                            VStack(spacing: Theme.Spacing.md) {
                                ForEach(upcoming.dropFirst()) { exam in
                                    examRow(exam)
                                }
                            }
                        }
                        crammingCard
                    }

                    addButton
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Mode Examens")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAdd) {
                AddExamSheet { title, date, icon, focusHabitID in
                    let exam = Exam(title: title, date: date, icon: icon, focusHabitID: focusHabitID)
                    modelContext.insert(exam)
                    try? modelContext.save()
                }
            }
            .sheet(item: $focusExam) { exam in
                FocusSessionSheet(store: store, exam: exam)
            }
            .sheet(isPresented: $showPremium) {
                PremiumView(storeManager: store.storeManager, context: .general)
            }
        }
    }

    // MARK: - Sous-vues

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentGradient)
            Text("Traverse tes partiels, sereinement")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Ajoute tes examens : Steady t'aide à réviser et allège la pression pendant le rush.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    /// Compte à rebours héros du prochain examen.
    private func heroCountdown(_ exam: Exam) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: exam.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.18)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.title).font(.headline).foregroundStyle(.white).lineLimit(1)
                    Text(exam.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(exam.daysRemaining == 0 ? L("C'est aujourd'hui") : "J-\(exam.daysRemaining)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer()
            }

            // Focus révision (Premium).
            Button {
                if isPremium { focusExam = exam } else { showPremium = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPremium ? "timer" : "lock.fill")
                    Text("Lancer une session de révision")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentDeep)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(.white))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(exam.urgency == .critical ? AnyShapeStyle(LinearGradient(colors: [.orange, Color(red: 0.85, green: 0.35, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.accentGradient))
        )
        .shadow(color: Color.brandAccent.opacity(0.3), radius: 14, y: 8)
        .contextMenu {
            Button(role: .destructive) { delete(exam) } label: { Label("Supprimer", systemImage: "trash") }
        }
    }

    private func examRow(_ exam: Exam) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: exam.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(urgencyColor(exam.urgency).gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(exam.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(exam.date, format: .dateTime.day().month(.wide))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("J-\(exam.daysRemaining)")
                .font(.headline.weight(.bold))
                .foregroundStyle(urgencyColor(exam.urgency))
        }
        .padding(Theme.Spacing.md)
        .steadyCard()
        .contextMenu {
            Button(role: .destructive) { delete(exam) } label: { Label("Supprimer", systemImage: "trash") }
        }
    }

    /// Carte « allègement partiels » : protège les séries pendant le rush.
    private var crammingCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Allègement partiels", systemImage: "moon.zzz.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentDeep)
            Text("En période d'examens, active le jour de repos : tes séries restent protégées même si tu mets tes habitudes en pause pour réviser. Zéro culpabilité.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle(isOn: Binding(get: { store.isRestDay }, set: { newValue in
                withAnimation { store.isRestDay = newValue }
                HapticManager.lightImpact()
            })) {
                Text(store.isRestDay ? "Repos actif, séries protégées" : "Activer le repos aujourd'hui")
                    .font(.subheadline.weight(.medium))
            }
            .tint(Color.accentDeep)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Aucun examen pour l'instant")
                .font(.headline)
            Text("Ajoute ton prochain partiel pour voir le compte à rebours et débloquer le mode révision.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Theme.Spacing.lg)
    }

    private var addButton: some View {
        Button {
            showAdd = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                Text("Ajouter un examen")
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(Color.accentGradient))
        }
        .buttonStyle(.plain)
    }

    private func urgencyColor(_ u: ExamUrgency) -> Color {
        switch u {
        case .critical: return .orange
        case .soon: return Color.steadyFlame
        case .calm: return .accentDeep
        case .past: return .secondary
        }
    }

    private func delete(_ exam: Exam) {
        modelContext.delete(exam)
        try? modelContext.save()
    }
}

// MARK: - Ajout d'examen

private struct AddExamSheet: View {
    var onAdd: (String, Date, String, UUID?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Habit.sortIndex)]) private var habits: [Habit]

    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var icon = "graduationcap.fill"
    @State private var focusHabit: Habit?

    private static let icons = ["graduationcap.fill", "book.fill", "function", "flask.fill",
                                "globe.europe.africa.fill", "brain.head.profile", "pencil.and.ruler.fill", "text.book.closed.fill"]

    private var canAdd: Bool { title.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    field("Matière / examen") {
                        TextField("Ex. Partiel de Maths", text: $title)
                            .padding(Theme.Spacing.md)
                            .steadyCard(cornerRadius: Theme.Radius.md)
                    }

                    field("Icône") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: Theme.Spacing.sm) {
                            ForEach(Self.icons, id: \.self) { symbol in
                                Button {
                                    icon = symbol; HapticManager.lightImpact()
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.subheadline)
                                        .foregroundStyle(icon == symbol ? .white : Color.accentDeep)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(icon == symbol ? Color.accentDeep : Color.accentDeep.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .steadyCard(cornerRadius: Theme.Radius.md)
                    }

                    field("Date de l'examen") {
                        DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Color.accentDeep)
                            .padding(Theme.Spacing.sm)
                            .steadyCard(cornerRadius: Theme.Radius.md)
                    }

                    if !habits.isEmpty {
                        field("Habitude de révision (optionnel)") {
                            Menu {
                                Button(L("Aucune")) { focusHabit = nil }
                                ForEach(habits) { habit in
                                    Button(habit.name) { focusHabit = habit }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: focusHabit?.icon ?? "book.fill")
                                    Text(focusHabit?.name ?? L("Choisir une habitude"))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                                }
                                .padding(Theme.Spacing.md)
                                .steadyCard(cornerRadius: Theme.Radius.md)
                            }
                        }
                    }

                    Button {
                        onAdd(title.trimmingCharacters(in: .whitespaces), date, icon, focusHabit?.id)
                        dismiss()
                    } label: {
                        Text("Ajouter l'examen")
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(canAdd ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.secondary.opacity(0.3))))
                    }
                    .disabled(!canAdd)
                }
                .padding(.horizontal).padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Nouvel examen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } } }
        }
    }

    private func field<Content: View>(_ label: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label).font(.subheadline.weight(.semibold))
            content()
        }
    }
}

// MARK: - Session de révision (Pomodoro)

private struct FocusSessionSheet: View {
    var store: HabitStore
    let exam: Exam
    @Environment(\.dismiss) private var dismiss

    @State private var minutes = 25
    @State private var endDate: Date?
    @State private var totalSeconds: TimeInterval = 25 * 60   // durée de la session en cours (pour l'anneau)
    @State private var finished = false

    var body: some View {
        ZStack {
            // Fond premium plein écran (bord à bord).
            LinearGradient(colors: [Color.accentDeep, Color.brandAccent],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle().fill(.white.opacity(0.08))
                .frame(width: 340, height: 340)
                .offset(x: -130, y: -300)
            Circle().fill(.white.opacity(0.06))
                .frame(width: 260, height: 260)
                .offset(x: 150, y: 320)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .presentationBackground(.clear)
        .presentationDetents([.large])
        .interactiveDismissDisabled(endDate != nil)   // pas de fermeture accidentelle en pleine session
    }

    // MARK: - Barre du haut

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 1) {
                Text("Révision focus").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(exam.title).font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
            }
            Spacer()
            Color.clear.frame(width: 38, height: 38)   // équilibre visuel
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Contenu (3 états)

    @ViewBuilder private var content: some View {
        if let endDate {
            runningRing(endDate)
        } else if finished {
            finishedState
        } else {
            setupState
        }
    }

    /// Anneau de progression + décompte (session active).
    private func runningRing(_ endDate: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            let progress = totalSeconds > 0 ? min(1, (totalSeconds - remaining) / totalSeconds) : 0
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                VStack(spacing: 6) {
                    Text(timeString(remaining))
                        .font(.system(size: 62, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("Reste concentré")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(width: 300, height: 300)
            .onChange(of: context.date) { _, now in
                if now >= endDate && !finished { complete() }
            }
        }
    }

    private var setupState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: 88, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("minutes de concentration")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }
            HStack(spacing: Theme.Spacing.md) {
                ForEach([15, 25, 50], id: \.self) { m in
                    Button {
                        withAnimation(.snappy) { minutes = m }; HapticManager.lightImpact()
                    } label: {
                        Text("\(m)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(minutes == m ? Color.accentDeep : .white)
                            .frame(width: 68, height: 52)
                            .background(
                                Capsule().fill(minutes == m ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.18)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var finishedState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white)
            Text("Session terminée !")
                .font(.title.weight(.heavy)).foregroundStyle(.white)
            Text("Bien joué. Une brique de plus vers ton examen.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    // MARK: - Bouton du bas (change selon l'état)

    @ViewBuilder private var footer: some View {
        if endDate != nil {
            Button { withAnimation { endDate = nil } } label: {
                Text("Arrêter")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Capsule().fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
        } else if finished {
            Button { dismiss() } label: {
                Text("Terminer")
                    .font(.headline).foregroundStyle(Color.accentDeep)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        } else {
            Button {
                totalSeconds = TimeInterval(minutes * 60)
                withAnimation { endDate = Date().addingTimeInterval(totalSeconds) }
                HapticManager.success()
            } label: {
                Label("Démarrer", systemImage: "play.fill")
                    .font(.headline).foregroundStyle(Color.accentDeep)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func complete() {
        finished = true
        endDate = nil
        HapticManager.success()
        // Valide l'habitude de révision liée, si présente.
        if let id = exam.focusHabitID,
           let habit = try? store.habit(with: id) {
            store.markDoneFromFocus(habit)
        }
    }
}
