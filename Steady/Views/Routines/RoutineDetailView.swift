import SwiftUI

/// Aperçu d'une routine + installation.
struct RoutineDetailView: View {
    let routine: RoutineTemplate
    var store: HabitStore
    var onInstalled: () -> Void

    @State private var showPremium = false

    private var isPremium: Bool { store.storeManager.isPremium }
    /// Les routines de niveau avancé sont réservées au Premium.
    private var isLocked: Bool {
        if case .advanced = routine.level { return !isPremium }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                hero

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Habitudes incluses").font(.headline)
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(routine.habits) { spec in
                            habitRow(spec)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                installButton
            }
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(AnimatedBackground())
        .navigationTitle("Routine")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremium) {
            PremiumView(storeManager: store.storeManager)
        }
    }

    private var hero: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: routine.icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(Circle().fill(routine.category.color.gradient))
                .shadow(color: routine.category.color.opacity(0.35), radius: 12, y: 6)
            Text(routine.name).font(.title2.weight(.bold)).multilineTextAlignment(.center)
            Text(routine.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: Theme.Spacing.md) {
                RoutineChip(text: routine.duration, icon: "clock", tint: .secondary)
                RoutineChip(text: routine.level.label, icon: "chart.bar.fill", tint: routine.level.color)
            }
            .padding(.top, 2)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private func habitRow(_ spec: RoutineTemplate.HabitSpec) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: spec.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.accentGradient))
            Text(spec.name).font(.body.weight(.medium))
            Spacer()
            if spec.goal > 1 {
                Text("\(spec.goal)\(spec.unit.isEmpty ? "" : " \(spec.unit)")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentDeep)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard(cornerRadius: Theme.Radius.md)
    }

    private var installButton: some View {
        Button {
            if isLocked {
                showPremium = true
            } else {
                store.installRoutine(routine.habits)
                HapticManager.success()
                onInstalled()
            }
        } label: {
            HStack(spacing: 8) {
                if isLocked { Image(systemName: "lock.fill") }
                Text(isLocked ? "Débloquer avec Premium" : "Installer la routine")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .shadow(color: Color.brandAccent.opacity(0.35), radius: 12, y: 6)
        }
    }
}
