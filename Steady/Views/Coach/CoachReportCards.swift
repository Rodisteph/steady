import SwiftUI

// MARK: - Bilan hebdomadaire

struct WeeklyReviewCard: View {
    let review: WeeklyReview
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Bilan de la semaine", systemImage: "calendar.badge.clock")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                MiniStat(value: "\(review.successRate)%", label: "Réussite", icon: "checkmark.seal.fill")
                MiniStat(value: "\(review.completed)", label: "Validations", icon: "checkmark.circle.fill")
                MiniStat(value: "\(review.longestStreak) j", label: "Plus longue série", icon: "flame.fill")
                MiniStat(value: "\(review.averageStreak) j", label: "Série moyenne", icon: "chart.bar.fill")
            }

            if let best = review.bestHabit {
                infoLine(icon: "star.fill", text: L("Habitude phare : « \(best) »"))
            }
            if let weak = review.weakestHabit {
                infoLine(icon: "lightbulb.fill", text: L("À soigner : « \(weak) »"))
            }
            infoLine(icon: "sun.max.fill", text: L("Meilleur jour : \(review.bestDay) · Plus dur : \(review.worstDay)"))

            Text(review.summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 14)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { appear = true } }
    }

    private func infoLine(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(Color.accentDeep).frame(width: 18)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rapport mensuel

struct MonthlyReportCard: View {
    let report: MonthlyReport
    @State private var appear = false
    @State private var shownRate = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Rapport du mois", systemImage: "chart.pie.fill")
                .font(.headline)

            HStack(spacing: Theme.Spacing.md) {
                // Anneau de complétion animé.
                ZStack {
                    Circle().stroke(Color.brandAccent.opacity(0.15), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: max(0.001, CGFloat(shownRate) / 100))
                        .stroke(Color.accentGradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(shownRate)%")
                        .font(.headline.weight(.bold))
                        .contentTransition(.numericText())
                }
                .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 6) {
                    trend
                    stat(icon: "checkmark.circle.fill", text: L("\(report.totalCompleted) validations"))
                    if report.newRecords > 0 {
                        stat(icon: "crown.fill", text: L("\(report.newRecords) record(s) en cours"))
                    }
                    if report.missedHabits > 0 {
                        stat(icon: "moon.zzz.fill", text: L("\(report.missedHabits) habitude(s) en pause"))
                    }
                    stat(icon: "sun.max.fill", text: L("Meilleur jour : \(report.bestDay)"))
                }
                Spacer(minLength: 0)
            }

            Text(report.summary)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .scaleEffect(appear ? 1 : 0.94)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { appear = true }
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) { shownRate = report.completionRate }
        }
    }

    private var trend: some View {
        HStack(spacing: 6) {
            Image(systemName: report.evolution >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.bold))
            Text(report.evolution >= 0 ? L("+\(report.evolution) pts vs mois dernier") : L("\(report.evolution) pts vs mois dernier"))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(report.evolution >= 0 ? .green : .orange)
    }

    private func stat(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption2).foregroundStyle(Color.accentDeep).frame(width: 16)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Petite tuile de stat

private struct MiniStat: View {
    let value: String
    let label: LocalizedStringKey
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentDeep)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.brandAccent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.weight(.bold))
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
