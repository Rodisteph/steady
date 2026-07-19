import SwiftUI

// MARK: - Conseil du jour

struct DailyInsightCard: View {
    let insight: CoachDailyInsight
    @State private var appear = false
    /// Avis donné aujourd'hui (👍 / 👎) → fige les boutons et remercie.
    @State private var feedback: Bool? = nil

    private var memory: CoachMemory { CoachMemory.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle().fill(Color.accentGradient).frame(width: 50, height: 50)
                        .shadow(color: Color.brandAccent.opacity(0.4), radius: 10, y: 5)
                    Image(systemName: insight.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: appear)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conseil du jour")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentDeep)
                    Text(insight.text)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            // Apprentissage : l'avis re-pondère ce type de conseil pour la suite.
            if let feedback {
                Label(feedback ? "Noté. Le coach t'en proposera plus comme ça."
                               : "Compris. Le coach évitera ce genre de conseil.",
                      systemImage: feedback ? "checkmark.circle.fill" : "hand.thumbsdown.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if !memory.todayFeedbackGiven {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Ce conseil t'aide ?").font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    feedbackButton(helpful: true, icon: "hand.thumbsup.fill")
                    feedbackButton(helpful: false, icon: "hand.thumbsdown")
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 12)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appear = true } }
    }

    private func feedbackButton(helpful: Bool, icon: String) -> some View {
        Button {
            memory.reinforce(insight.tag, helpful: helpful)
            withAnimation(.spring(response: 0.3)) { feedback = helpful }
        } label: {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(helpful ? Color.accentDeep : .secondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.brandAccent.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(helpful ? "Conseil utile" : "Conseil inutile")
    }
}

// MARK: - Prédictions

struct PredictionCard: View {
    let prediction: CoachPrediction
    @State private var shownChance = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Prédictions", systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: Theme.Spacing.md) {
                metric(
                    value: "\(shownChance)%",
                    label: "Réussite aujourd'hui",
                    tint: Color.accentDeep
                )
                divider
                metric(
                    value: prediction.motivation.label,
                    label: "Motivation demain",
                    tint: color(for: prediction.motivation, goodIsHigh: true)
                )
                divider
                metric(
                    value: prediction.streakRisk.label,
                    label: "Risque de série",
                    tint: color(for: prediction.streakRisk, goodIsHigh: false)
                )
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { shownChance = prediction.todayChance }
        }
    }

    private func metric(value: String, label: LocalizedStringKey, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1, height: 38)
    }

    private func color(for level: CoachLevel, goodIsHigh: Bool) -> Color {
        switch level {
        case .high: return goodIsHigh ? .green : .red
        case .medium: return .orange
        case .low: return goodIsHigh ? .secondary : .green
        }
    }
}

// MARK: - Suggestions intelligentes

struct SuggestionsCard: View {
    let suggestions: [CoachSuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Suggestions", systemImage: "lightbulb.fill")
                .font(.headline)
            ForEach(suggestions) { s in
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: s.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentDeep)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.brandAccent.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).font(.subheadline.weight(.semibold))
                        Text(s.text).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }
}
