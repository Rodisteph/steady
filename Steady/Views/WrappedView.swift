import SwiftUI

/// Données du récap « Steady Wrapped » (façon Spotify Wrapped).
struct WrappedData {
    let totalValidations: Int
    let bestStreak: Int
    let activeDays: Int
    let level: Int
    let topHabitName: String?
    let starWeekday: String?
    let archetype: WrappedArchetype
    let periodLabel: String
}

/// « Personnalité » de l'utilisateur — l'équivalent du genre musical de Spotify.
enum WrappedArchetype {
    case earlyBird, streakMaster, weekendWarrior, consistent, rising

    var title: LocalizedStringKey {
        switch self {
        case .earlyBird:      return "Lève-tôt discipliné"
        case .streakMaster:   return "Maître des séries"
        case .weekendWarrior: return "Warrior du week-end"
        case .consistent:     return "Machine à régularité"
        case .rising:         return "En pleine ascension"
        }
    }
    /// Version `String` (localisée immédiatement) — indispensable pour l'image
    /// partagée : `ImageRenderer` n'hérite pas de la locale de l'environnement.
    var titleText: String {
        switch self {
        case .earlyBird:      return L("Lève-tôt discipliné")
        case .streakMaster:   return L("Maître des séries")
        case .weekendWarrior: return L("Warrior du week-end")
        case .consistent:     return L("Machine à régularité")
        case .rising:         return L("En pleine ascension")
        }
    }
    var emoji: String {
        switch self {
        case .earlyBird: return "🌅"
        case .streakMaster: return "🔥"
        case .weekendWarrior: return "🏆"
        case .consistent: return "⚙️"
        case .rising: return "🚀"
        }
    }
}

enum WrappedBuilder {
    /// Construit le récap depuis les données réelles.
    @MainActor
    static func build(habits: [Habit], store: HabitStore, thisYear: Bool) -> WrappedData {
        let analytics = AnalyticsService()
        let active = habits.filter { !$0.records.isEmpty }
        let cal = Calendar.current

        let total = active.reduce(0) { $0 + store.totalCompletions(for: $1) }
        let best = active.map { store.longestStreak(for: $0) }.max() ?? 0
        let days = Set(active.flatMap { h in
            h.records.filter { $0.count >= h.dailyGoal }.map { cal.startOfDay(for: $0.date) }
        }).count

        let ranked = active.map { (name: $0.name, n: store.totalCompletions(for: $0)) }.sorted { $0.n > $1.n }
        // Re-localise le nom : les habitudes issues du catalogue sont figées dans la
        // langue du seed. Repasser par L() les traduit dans la langue choisie in-app
        // (un nom custom absent du catalogue est renvoyé tel quel).
        let topHabit = ranked.first.map { L(String.LocalizationValue($0.name)) }

        var starDay: String?
        if let bw = analytics.bestWorstWeekday(active) { starDay = analytics.weekdayName(bw.best) }

        // Archétype : quelques règles simples sur les données réelles.
        let consistency = analytics.consistencyScore(active)
        let arch: WrappedArchetype
        if best >= 21 { arch = .streakMaster }
        else if consistency >= 75 { arch = .consistent }
        else if let bw = analytics.bestWorstWeekday(active), bw.best == 1 || bw.best == 7 { arch = .weekendWarrior }
        else if days >= 14 { arch = .earlyBird }
        else { arch = .rising }

        let period = thisYear ? L("Mon année Steady") : L("Mon mois Steady")
        return WrappedData(totalValidations: thisYear ? total : store.monthlyTotal(among: active),
                           bestStreak: best, activeDays: days, level: GamificationManager.shared.level,
                           topHabitName: topHabit, starWeekday: starDay, archetype: arch, periodLabel: period)
    }
}

// MARK: - Écran Wrapped

struct WrappedView: View {
    var store: HabitStore
    let habits: [Habit]
    @Environment(\.dismiss) private var dismiss

    @State private var thisYear = true
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @State private var showPremium = false

    private var isPremium: Bool { store.storeManager.isPremium }
    private var data: WrappedData { WrappedBuilder.build(habits: habits, store: store, thisYear: thisYear) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    Picker("", selection: $thisYear) {
                        Text("Ce mois").tag(false)
                        Text("Cette année").tag(true)
                    }
                    .pickerStyle(.segmented)

                    WrappedCard(data: data, watermark: !isPremium)
                        .frame(maxWidth: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)

                    Button {
                        share()
                    } label: {
                        Label("Partager mon Wrapped", systemImage: "square.and.arrow.up")
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(Color.accentGradient))
                    }
                    .buttonStyle(.plain)

                    if !isPremium {
                        Button { showPremium = true } label: {
                            Label("Retirer le filigrane avec Premium", systemImage: "crown.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentDeep)
                        }
                    }
                }
                .padding(.horizontal).padding(.top, Theme.Spacing.sm).padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Steady Wrapped")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
            .sheet(isPresented: $showShare) {
                if let shareImage { ShareSheet(items: [shareImage]) }
            }
            .sheet(isPresented: $showPremium) {
                PremiumView(storeManager: store.storeManager, context: .general)
            }
        }
    }

    @MainActor private func share() {
        let renderer = ImageRenderer(content:
            WrappedCard(data: data, watermark: !isPremium)
                .frame(width: 1080, height: 1920)
                .environment(\.locale, LocalizationManager.shared.locale)
        )
        renderer.scale = 1
        if let image = renderer.uiImage {
            shareImage = image
            showShare = true
        }
    }
}

// MARK: - La carte (format story, partageable)

struct WrappedCard: View {
    let data: WrappedData
    var watermark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En-tête
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                    Text("Steady").font(.title3.weight(.heavy))
                    Spacer()
                    Image(systemName: "sparkles")
                }
                .foregroundStyle(.white.opacity(0.9))
                Text(data.periodLabel)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 22)

            // Archétype (le « genre »)
            VStack(alignment: .leading, spacing: 2) {
                Text(data.archetype.emoji).font(.system(size: 44))
                Text(L("Ton profil"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                Text(data.archetype.titleText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 24)

            // Chiffres clés
            HStack(spacing: 12) {
                stat("\(data.totalValidations)", L("validations"))
                stat("\(data.bestStreak)", L("record 🔥"))
            }
            .padding(.bottom, 12)
            HStack(spacing: 12) {
                stat("\(data.activeDays)", L("jours actifs"))
                stat("\(L("Niv.")) \(data.level)", L("niveau"))
            }
            .padding(.bottom, 18)

            if let top = data.topHabitName {
                line(L("Habitude reine"), top)
            }
            if let star = data.starWeekday {
                line(L("Jour star"), star)
            }

            Spacer(minLength: 12)

            if watermark {
                Text(L("fait avec Steady · steadyapp"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color(red: 0.56, green: 0.69, blue: 0.63),
                                    Color(red: 0.34, green: 0.46, blue: 0.40)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.15)))
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(.white).lineLimit(1)
        }
        .padding(.vertical, 6)
    }
}
