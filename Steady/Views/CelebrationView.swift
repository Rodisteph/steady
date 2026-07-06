import SwiftUI

/// Overlay festif affiché quand toutes les habitudes du jour sont validées.
struct CelebrationView: View {
    @Binding var isPresented: Bool

    @State private var animate = false
    @State private var cardIn = false

    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat          // 0...1
        let delay: Double
        let duration: Double
        let size: CGFloat
        let color: Color
        let rotation: Double
        let isCircle: Bool
    }

    /// Valeurs animées du badge central (pop via KeyframeAnimator).
    private struct BadgePop {
        var scale: CGFloat = 0.5
        var angle: Double = 0
    }

    private let particles: [Particle] = {
        let colors: [Color] = [
            .brandAccent, .steadyFlame,
            Color(red: 0.47, green: 0.60, blue: 0.54),
            Color(red: 0.96, green: 0.72, blue: 0.35)
        ]
        return (0..<90).map { _ in
            Particle(
                x: .random(in: 0...1),
                delay: .random(in: 0...0.7),
                duration: .random(in: 1.6...3.0),
                size: .random(in: 6...13),
                color: colors.randomElement() ?? .brandAccent,
                rotation: .random(in: 0...360),
                isCircle: .random()
            )
        }
    }()

    @ViewBuilder
    private func confetto(_ p: Particle) -> some View {
        if p.isCircle {
            Circle()
                .fill(p.color)
                .frame(width: p.size, height: p.size)
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(p.color)
                .frame(width: p.size, height: p.size * 1.4)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(cardIn ? 0.12 : 0)
                    .ignoresSafeArea()

                // Confettis (formes variées)
                ForEach(particles) { p in
                    confetto(p)
                        .rotationEffect(.degrees(animate ? p.rotation + 220 : p.rotation))
                        .position(
                            x: p.x * geo.size.width,
                            y: animate ? geo.size.height + 40 : -40
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(.easeIn(duration: p.duration).delay(p.delay), value: animate)
                }

                // Carte centrale
                VStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.accentGradient)
                            .frame(width: 96, height: 96)
                            .shadow(color: Color.brandAccent.opacity(0.4), radius: 16, y: 8)
                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white)
                            .symbolEffect(.bounce, value: cardIn)
                    }
                    .keyframeAnimator(initialValue: BadgePop()) { view, v in
                        view.scaleEffect(v.scale).rotationEffect(.degrees(v.angle))
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.18, duration: 0.35, spring: .bouncy)
                            SpringKeyframe(1.0, duration: 0.35)
                        }
                        KeyframeTrack(\.angle) {
                            CubicKeyframe(-8, duration: 0.18)
                            CubicKeyframe(8, duration: 0.18)
                            CubicKeyframe(0, duration: 0.18)
                        }
                    }

                    Text("Tout est validé !")
                        .font(.title2.weight(.bold))
                    Text("Bravo, continue comme ça.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .fill(Color.steadyCard)
                        .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
                )
                .scaleEffect(cardIn ? 1 : 0.8)
                .opacity(cardIn ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            HapticManager.success()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { cardIn = true }
            withAnimation { animate = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeOut(duration: 0.3)) { cardIn = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPresented = false
                }
            }
        }
    }
}
