import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Palette du widget (fond dégradé coloré + contenu blanc = lisible jour & nuit)
// Le dégradé suit le thème choisi dans l'app (transmis en hex via l'App Group).

private let onBrand = Color.white
private let onBrandSoft = Color.white.opacity(0.78)
private let flame = Color(red: 1.0, green: 0.78, blue: 0.45)

private extension Color {
    /// Couleur depuis un hex "RRGGBB" (repli : sauge).
    init(hex: String) {
        var value: UInt64 = 0
        guard hex.count == 6, Scanner(string: hex).scanHexInt64(&value) else {
            self = Color(red: 0.56, green: 0.69, blue: 0.63)
            return
        }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

// MARK: - Timeline

struct SteadyEntry: TimelineEntry {
    let date: Date
    let snapshot: SteadyWidgetSnapshot
}

struct Provider: TimelineProvider {
    private var sample: SteadyWidgetSnapshot {
        SteadyWidgetSnapshot(completed: 3, total: 4, weeklyTotal: 18, bestStreak: 7, habits: [
            .init(name: "Méditer", icon: "brain.head.profile", done: true),
            .init(name: "Lire 10 pages", icon: "book.fill", done: true),
            .init(name: "Boire de l'eau", icon: "drop.fill", done: true),
            .init(name: "Courir", icon: "figure.run", done: false)
        ])
    }

    func placeholder(in context: Context) -> SteadyEntry { SteadyEntry(date: Date(), snapshot: sample) }

    func getSnapshot(in context: Context, completion: @escaping (SteadyEntry) -> Void) {
        let snap = context.isPreview ? sample : SteadyWidgetStore.load()
        completion(SteadyEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SteadyEntry>) -> Void) {
        let entry = SteadyEntry(date: Date(), snapshot: SteadyWidgetStore.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Briques réutilisables

private struct WidgetRing: View {
    let completed: Int
    let total: Int
    var size: CGFloat = 60
    var showPercent: Bool = false

    private var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    private var percent: Int { Int((progress * 100).rounded()) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.25), lineWidth: size * 0.12)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(onBrand, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if total > 0 && completed == total {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(onBrand)
            } else {
                Text(showPercent ? "\(percent)%" : "\(completed)/\(total)")
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundStyle(onBrand)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct StreakChip: View {
    let value: Int
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").foregroundStyle(flame)
            Text("\(value)").foregroundStyle(onBrand)
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.18)))
    }
}

private struct HabitRow: View {
    let item: SteadyWidgetSnapshot.Item
    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleHabitIntent(habitID: item.id)) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(item.done ? onBrand : onBrand.opacity(0.5))
            }
            .buttonStyle(.plain)
            // L'icône de l'habitude : on la reconnaît d'un coup d'œil.
            Image(systemName: item.icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.done ? onBrandSoft : onBrand.opacity(0.9))
                .frame(width: 16)
            Text(item.name)
                .font(.subheadline.weight(.medium))
                .strikethrough(item.done, color: onBrandSoft)
                .foregroundStyle(item.done ? onBrandSoft : onBrand)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Vue principale

struct SteadyWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry
    private var s: SteadyWidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemLarge: largeView
        default: mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Steady").font(.headline.weight(.bold)).foregroundStyle(onBrand)
                Spacer()
                if s.bestStreak > 0 { StreakChip(value: s.bestStreak) }
            }
            Spacer()
            HStack { Spacer(); WidgetRing(completed: s.completed, total: s.total, size: 78, showPercent: true); Spacer() }
            Spacer()
            Text("Aujourd'hui").font(.caption2.weight(.medium)).foregroundStyle(onBrandSoft)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                WidgetRing(completed: s.completed, total: s.total, size: 64)
                if s.bestStreak > 0 { StreakChip(value: s.bestStreak) }
            }
            VStack(alignment: .leading, spacing: 7) {
                if s.habits.isEmpty {
                    Text("Ajoutez une habitude").font(.subheadline).foregroundStyle(onBrandSoft)
                } else {
                    ForEach(s.habits.prefix(4), id: \.self) { HabitRow(item: $0) }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                WidgetRing(completed: s.completed, total: s.total, size: 64, showPercent: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Steady").font(.headline.weight(.bold)).foregroundStyle(onBrand)
                    // Deux Text distincts : un ternaire de String échapperait à la localisation.
                    Group {
                        if s.completed == s.total && s.total > 0 {
                            Text("Tout est validé !")
                        } else {
                            Text("\(s.completed)/\(s.total) aujourd'hui")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(onBrandSoft)
                }
                Spacer()
            }

            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)

            if s.habits.isEmpty {
                Spacer()
                Text("Ajoutez une habitude dans l'app")
                    .font(.subheadline).foregroundStyle(onBrandSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(s.habits.prefix(5), id: \.self) { HabitRow(item: $0) }
                }
            }

            Spacer(minLength: 0)
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)

            HStack {
                statFoot(value: "\(s.weeklyTotal)", label: "cette semaine", icon: "checkmark.circle.fill")
                Spacer()
                statFoot(value: "\(s.bestStreak)", label: "série", icon: "flame.fill")
            }
        }
    }

    private func statFoot(value: String, label: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(icon == "flame.fill" ? flame : onBrand)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(onBrand)
            Text(label).font(.caption).foregroundStyle(onBrandSoft)
        }
    }
}

// MARK: - Widget

struct Steadywidget: Widget {
    let kind: String = "Steadywidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SteadyWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        // Le dégradé suit le thème choisi dans l'app.
                        LinearGradient(
                            colors: [Color(hex: entry.snapshot.gradientTop),
                                     Color(hex: entry.snapshot.gradientBottom)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        // Voile lumineux discret (effet « glass » premium).
                        LinearGradient(colors: [Color.white.opacity(0.20), .clear],
                                       startPoint: .topLeading, endPoint: .center)
                    }
                }
        }
        .configurationDisplayName("Steady")
        .description("Vos habitudes du jour et votre progression.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    Steadywidget()
} timeline: {
    SteadyEntry(date: .now, snapshot: SteadyWidgetSnapshot(completed: 3, total: 4, weeklyTotal: 18, bestStreak: 7, habits: [
        .init(name: "Méditer", icon: "brain.head.profile", done: true),
        .init(name: "Lire 10 pages", icon: "book.fill", done: true),
        .init(name: "Boire de l'eau", icon: "drop.fill", done: true),
        .init(name: "Courir", icon: "figure.run", done: false)
    ]))
}
