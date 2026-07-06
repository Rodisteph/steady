import SwiftUI
import SwiftData

/// Écran du coach IA on-device : motivation du jour + conseils personnalisés.
struct CoachScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Habit.sortIndex), SortDescriptor(\Habit.creationDate)]) private var habits: [Habit]

    var store: HabitStore

    @State private var viewModel = CoachViewModel()
    @State private var showPremium = false
    @State private var showSocial = false

    private var isPremium: Bool { store.storeManager.isPremium }

    /// Meilleure série en cours, partagée avec le profil social.
    private var bestStreak: Int {
        habits.map { store.currentStreak(for: $0) }.max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(spacing: 0) {
                SteadyTitle("Coach")
                VStack(spacing: Theme.Spacing.lg) {
                    LevelBar()
                    MotivationCard(text: viewModel.motivation)

                    if isPremium {
                        if let daily = viewModel.dailyInsight {
                            DailyInsightCard(insight: daily)
                        }
                        if let prediction = viewModel.prediction {
                            PredictionCard(prediction: prediction)
                        }
                        MoodCard(habits: habits, store: store)
                        if !viewModel.suggestions.isEmpty {
                            SuggestionsCard(suggestions: viewModel.suggestions)
                        }
                        if let weekly = viewModel.weeklyReview {
                            WeeklyReviewCard(review: weekly)
                        }
                        if let monthly = viewModel.monthlyReport {
                            MonthlyReportCard(report: monthly)
                        }
                        if !viewModel.insights.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Tes insights")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(viewModel.insights) { insight in
                                    InsightCard(insight: insight)
                                }
                            }
                        }
                        if viewModel.dailyInsight == nil && viewModel.insights.isEmpty {
                            emptyState
                        }
                    } else if viewModel.insights.isEmpty && viewModel.dailyInsight == nil {
                        emptyState
                    } else {
                        lockedInsights
                    }
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
              }
            }
            .background(AnimatedBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPremium) {
                PremiumView(storeManager: store.storeManager)
            }
            .onAppear {
                store.configure(with: modelContext)
                viewModel.refresh(habits: habits, store: store)
            }
            .onChange(of: habits.count) { _, _ in
                viewModel.refresh(habits: habits, store: store)
            }
        }
    }

    private var lockedInsights: some View {
        Button {
            showPremium = true
        } label: {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentGradient)
                Text("Tes insights t'attendent")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Ton coach a analysé tes habitudes. Passe à Premium pour découvrir tes conseils personnalisés.")
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

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentGradient)
            Text("Ton coach apprend")
                .font(.title3.weight(.bold))
            Text("Valide tes habitudes quelques jours : ton coach analysera tes tendances et te donnera des conseils sur mesure.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
