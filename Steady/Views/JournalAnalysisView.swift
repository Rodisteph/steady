import SwiftUI

/// Feuille présentant l'analyse « coach » d'une entrée de journal.
struct JournalAnalysisView: View {
    let analysis: JournalAnalysis
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    section(L("Résumé"), icon: "text.alignleft", tint: .accentDeep, lines: [analysis.summary])
                    section(L("Points positifs"), icon: "hand.thumbsup.fill", tint: .green, lines: analysis.positives)
                    section(L("Axes d'amélioration"), icon: "arrow.up.forward.circle.fill", tint: .orange, lines: analysis.improvements)
                    section(L("Motivation pour demain"), icon: "sunrise.fill", tint: .accentDeep, lines: [analysis.motivation])
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Analyse du coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, icon: String, tint: Color, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(tint).frame(width: 5, height: 5).padding(.top, 7)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }
}
