import SwiftUI
import SwiftData

struct WeeklySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.creationDate) private var habits: [Habit]

    var store: HabitStore

    private let analytics = AnalyticsService()

    private var totalCompleted: Int {
        habits.reduce(0) { $0 + store.weeklySummary(for: $1) }
    }

    private var bestStreak: Int {
        habits.map { store.currentStreak(for: $0) }.max() ?? 0
    }

    /// Meilleure série jamais atteinte (persistée) — sert aux badges permanents.
    @AppStorage("steady_best_streak_ever") private var bestStreakEver = 0

    @State private var shareImage: UIImage?
    @State private var showShare = false
    @State private var showPremium = false

    private var isPremium: Bool { store.storeManager.isPremium }

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(spacing: 0) {
                SteadyTitle("Progrès")
                VStack(spacing: Theme.Spacing.lg) {
                    if habits.isEmpty {
                        ContentUnavailableView(
                            "Aucune donnée",
                            systemImage: "chart.bar",
                            description: Text("Ajoutez des habitudes pour voir vos statistiques.")
                        )
                        .padding(.top, 60)
                    } else {
                        weeklyHero

                        habitsWeekCard

                        MonthlyHeatmap(habits: habits, store: store)

                        BadgesSection(bestStreakEver: bestStreakEver)

                        advancedSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
              }
            }
            .background(AnimatedBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !habits.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            makeShareImage()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.accentDeep)
                        }
                        .accessibilityLabel("Partager ma semaine")
                    }
                }
            }
            .sheet(isPresented: $showShare) {
                if let shareImage {
                    ShareSheet(items: [shareImage])
                }
            }
            .sheet(isPresented: $showPremium) {
                PremiumView(storeManager: store.storeManager)
            }
            .onAppear { updateBestStreakEver() }
            .onChange(of: bestStreak) { _, _ in updateBestStreakEver() }
        }
    }

    @MainActor private func makeShareImage() {
        let lines = habits.prefix(4).map {
            ShareCardData.Line(name: $0.name, count: store.weeklySummary(for: $0))
        }
        let card = ShareCardView(data: .init(
            weeklyTotal: totalCompleted,
            bestStreak: bestStreak,
            habits: Array(lines)
        ))
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareImage = image
            showShare = true
        }
    }

    private func updateBestStreakEver() {
        if bestStreak > bestStreakEver {
            bestStreakEver = bestStreak
        }
    }

    // MARK: - Héros de la semaine (anneau animé + 2 chiffres clés, zéro doublon)

    @State private var heroProgress: Double = 0

    private var weekRate: Int { analytics.completionRate(habits, days: 7) }

    /// Titre d'ambiance selon la forme de la semaine — la page a une humeur.
    private var heroHeadline: String {
        switch weekRate {
        case 80...: return L("Semaine en feu 🔥")
        case 50..<80: return L("Belle semaine 💪")
        case 25..<50: return L("Ça se construit 🌱")
        default: return L("Nouveau départ ✨")
        }
    }

    private var weeklyHero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(heroHeadline)
                .font(.headline)
            HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle().stroke(Color.brandAccent.opacity(0.15), lineWidth: 11)
                Circle()
                    .trim(from: 0, to: max(0.001, heroProgress))
                    .stroke(Color.accentGradient, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(weekRate)%")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text("7 jours")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                heroStat(value: "\(bestStreak)", label: "Série en cours", icon: "flame.fill", tint: .steadyFlame)
                Rectangle().fill(Color.secondary.opacity(0.12)).frame(height: 1)
                heroStat(value: "\(totalCompleted)", label: "Validations (7j)", icon: "checkmark.circle.fill", tint: .accentDeep)
            }
            Spacer(minLength: 0)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .padding(.top, Theme.Spacing.sm)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                heroProgress = Double(weekRate) / 100
            }
        }
        .onChange(of: weekRate) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                heroProgress = Double(newValue) / 100
            }
        }
    }

    private func heroStat(value: String, label: LocalizedStringKey, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Semaine par habitude (compact, sans blabla)

    private var habitsWeekCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Cette semaine")
                .font(.headline)

            ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                if index > 0 {
                    Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1)
                }
                habitWeekRow(habit)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }

    private func habitWeekRow(_ habit: Habit) -> some View {
        let count = store.weeklySummary(for: habit)
        let scheduled = store.scheduledDaysLastWeek(for: habit)
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 10) {
                Image(systemName: habit.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.accentGradient))
                Text(habit.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if count >= scheduled && scheduled > 0 {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentDeep)
                }
                Text("\(count)/\(scheduled)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentDeep)
                    .contentTransition(.numericText())
            }
            WeekDotsRow(days: store.last7Days(for: habit))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(count) validations sur \(scheduled) jours prévus.")
    }

    // MARK: - Statistiques avancées (Premium)

    @ViewBuilder
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 6) {
                Text("Statistiques avancées").font(.headline)
                if !isPremium {
                    Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }

            if isPremium {
                AdvancedStatsContent(habits: habits, store: store)
            } else {
                lockedAdvancedTeaser
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private var lockedAdvancedTeaser: some View {
        Button {
            showPremium = true
        } label: {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentGradient)
                Text("Débloque tes tendances")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Taux de réussite, régularité, graphiques sur 14 jours et 8 semaines, meilleur et pire jour.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Débloquer avec Premium")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.accentGradient))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.xl)
            .steadyCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tuile de statistique

struct StatTile: View {
    let value: String
    let label: LocalizedStringKey
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.45)   // « Mercredi »/« Wednesday » tient sur une ligne
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .steadyCard(cornerRadius: Theme.Radius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Badges / récompenses

struct Badge: Identifiable {
    let milestone: Int
    let name: LocalizedStringKey
    let icon: String
    var id: Int { milestone }

    static let all: [Badge] = [
        Badge(milestone: 3, name: "Premiers pas", icon: "sparkles"),
        Badge(milestone: 7, name: "Une semaine", icon: "flame.fill"),
        Badge(milestone: 14, name: "Quinzaine", icon: "star.fill"),
        Badge(milestone: 30, name: "Un mois", icon: "rosette"),
        Badge(milestone: 60, name: "Inarrêtable", icon: "trophy.fill"),
        Badge(milestone: 100, name: "Légende", icon: "crown.fill")
    ]
}

struct BadgesSection: View {
    let bestStreakEver: Int

    private var earnedCount: Int {
        Badge.all.filter { bestStreakEver >= $0.milestone }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Récompenses")
                    .font(.headline)
                Spacer()
                Text("\(earnedCount)/\(Badge.all.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentDeep)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(Badge.all) { badge in
                        BadgeView(badge: badge, earned: bestStreakEver >= badge.milestone)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }
}

struct BadgeView: View {
    let badge: Badge
    let earned: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(earned ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadySurface))
                    .frame(width: 60, height: 60)
                    .shadow(color: earned ? Color.brandAccent.opacity(0.3) : .clear, radius: 8, y: 4)
                Image(systemName: earned ? badge.icon : "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(earned ? .white : Color.secondary.opacity(0.5))
            }
            Text(badge.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(earned ? .primary : .secondary)
                .lineLimit(1)
            Text("\(badge.milestone) j")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
        .opacity(earned ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(badge.name))
        .accessibilityHint(earned ? Text("Débloqué") : Text("Verrouillé — objectif : \(badge.milestone) jours"))
    }
}

// MARK: - Rangée de points (7 derniers jours)

struct WeekDotsRow: View {
    let days: [(date: Date, completed: Bool)]

    /// Formatter recalculé selon la langue choisie dans l'app (plus de fr_FR figé).
    private static func dayFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = LocalizationManager.shared.locale
        f.dateFormat = "EEEEE" // initiale du jour
        return f
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.date) { day in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(day.completed ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadySurface))
                            .frame(width: 26, height: 26)
                        if day.completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    Text(Self.dayFormatter().string(from: day.date).uppercased())
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}
