import SwiftUI

/// Carte « Ce mois-ci » : calendrier-heatmap des validations du mois courant.
struct MonthlyHeatmap: View {
    let habits: [Habit]
    let store: HabitStore

    private let calendar = Calendar.current

    var body: some View {
        let counts = store.monthlyCompletionCounts(among: habits)
        let total = max(habits.count, 1)
        let days = monthDays()

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Ce mois-ci")
                    .font(.headline)
                Spacer()
                Text(Date(), format: .dateTime.month(.wide).year())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentDeep)
            }

            HStack(spacing: 6) {
                ForEach(weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<leadingEmptyCount(), id: \.self) { _ in
                    Color.clear.frame(height: 30)
                }
                ForEach(days, id: \.self) { day in
                    let count = counts[calendar.startOfDay(for: day)] ?? 0
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(cellColor(count: count, total: total))
                        .frame(height: 30)
                        .overlay(
                            Text("\(calendar.component(.day, from: day))")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(count > 0 ? .white : .secondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.accentDeep, lineWidth: isToday(day) ? 2 : 0)
                        )
                }
            }

            Text("\(store.monthlyTotal(among: habits)) validations ce mois-ci")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calendrier du mois, \(store.monthlyTotal(among: habits)) validations.")
    }

    // MARK: - Helpers

    private func cellColor(count: Int, total: Int) -> AnyShapeStyle {
        if count == 0 { return AnyShapeStyle(Color.steadySurface) }
        let ratio = min(1.0, Double(count) / Double(total))
        return AnyShapeStyle(Color.brandAccent.opacity(0.35 + 0.65 * ratio))
    }

    private func isToday(_ day: Date) -> Bool {
        calendar.isDateInToday(day)
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
