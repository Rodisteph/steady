import SwiftUI

struct OnboardingView: View {
    /// Appelé quand l'utilisateur termine. `profile` = profil choisi (ou `nil` si passé).
    var onFinish: (HabitProfile?) -> Void

    @State private var page = 0
    @State private var showProfiles = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    // 3 écrans max : la valeur d'abord, la 1ʳᵉ habitude cochée en moins de 60 secondes.
    private let pages: [Page] = [
        .init(icon: "leaf.fill",
              title: "Bienvenue sur Steady",
              text: "Construis de meilleures habitudes, calmement, un jour à la fois."),
        .init(icon: "moon.fill",
              title: "Zéro culpabilité",
              text: "Des jours off sans casser ta série, un rythme qui te respecte. Ici, on avance en douceur."),
        .init(icon: "sparkles",
              title: "Un coach rien que pour toi",
              text: "Des conseils sur mesure, calculés sur ton téléphone. Tes données restent privées.")
    ]

    var body: some View {
        ZStack {
            AnimatedBackground()
            if showProfiles {
                profileChooser
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                intro
                    .transition(.opacity)
            }
        }
        // Plafonne la taille de police système sur ces écrans plein cadre :
        // au-delà, les textes débordaient. L'app elle-même reste 100 % adaptative.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    // MARK: - Intro (8 pages)

    private var intro: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, p in
                    OnboardingPageView(
                        icon: p.icon, title: p.title, text: p.text,
                        isCurrent: index == page, reduceMotion: reduceMotion
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: Theme.Spacing.lg) {
                progressBar
                continueButton
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    /// Progression segmentée en bas (le segment courant s'allonge en dégradé).
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.secondary.opacity(0.25)))
                    .frame(width: i == page ? 28 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: page)
        .accessibilityHidden(true)
    }

    private var continueButton: some View {
        Button {
            if page < pages.count - 1 {
                HapticManager.lightImpact()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page += 1 }
            } else {
                HapticManager.lightImpact()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { showProfiles = true }
            }
        } label: {
            Text(page < pages.count - 1 ? "Continuer" : "Commencer")
                .font(.headline)
                .contentTransition(.opacity)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .shadow(color: Color.brandAccent.opacity(0.4), radius: 14, y: 8)
        }
    }

    // MARK: - Choix de profil

    private var profileChooser: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(spacing: Theme.Spacing.sm) {
                Text("Par quoi veux-tu commencer ?")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text("On te prépare 3 habitudes pour démarrer en douceur.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Theme.Spacing.xl)
            .padding(.horizontal, Theme.Spacing.lg)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                ForEach(Array(HabitProfile.allCases.enumerated()), id: \.element) { index, profile in
                    Button {
                        HapticManager.success()
                        onFinish(profile)
                    } label: {
                        ProfileCard(profile: profile)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            Button {
                onFinish(nil)
            } label: {
                Text("Passer pour l'instant")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

// MARK: - Page d'onboarding (héros animé)

private struct OnboardingPageView: View {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let isCurrent: Bool
    let reduceMotion: Bool

    @State private var appear = false
    @State private var bounce = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            hero
            VStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)   // « Un coach rien que pour toi » tient sur petit écran
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.xl)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 18)
            Spacer()
            Spacer()
        }
        .onAppear { if isCurrent { trigger() } }
        .onChange(of: isCurrent) { _, now in if now { trigger() } }
    }

    private var hero: some View {
        ZStack {
            // Halo de glow pulsé.
            Circle()
                .fill(Color.brandAccent.opacity(0.35))
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .scaleEffect(reduceMotion ? 1 : (appear ? 1.05 : 0.9))

            Circle()
                .fill(Color.accentGradient)
                .frame(width: 140, height: 140)
                .shadow(color: Color.brandAccent.opacity(0.45), radius: 22, y: 12)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )

            Image(systemName: icon)
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: bounce)
        }
        .scaleEffect(appear ? 1 : 0.82)
        .modifier(FloatModifier(active: !reduceMotion))
    }

    private func trigger() {
        if reduceMotion {
            appear = true
            return
        }
        appear = false
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appear = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { bounce += 1 }
    }
}

/// Léger flottement vertical continu (PhaseAnimator).
private struct FloatModifier: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([false, true]) { view, up in
                view.offset(y: up ? -7 : 7)
            } animation: { _ in .easeInOut(duration: 2.6) }
        } else {
            content
        }
    }
}

private struct ProfileCard: View {
    let profile: HabitProfile

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.accentGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.brandAccent.opacity(0.35), radius: 10, y: 5)
                Image(systemName: profile.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(profile.title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .steadyCard(cornerRadius: Theme.Radius.lg)
    }
}
