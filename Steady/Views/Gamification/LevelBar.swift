import SwiftUI

/// Barre de progression de jeu : niveau, XP, pièces, avatar évolutif (réutilisable).
struct LevelBar: View {
    private var game = GamificationManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showShop = false
    @State private var glow = false

    var body: some View {
        Button {
            showShop = true
        } label: {
            content
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showShop) {
            AvatarShopView()
        }
    }

    private var content: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.brandAccent.opacity(0.45))
                    .frame(width: 50, height: 50)
                    .blur(radius: 9)
                    .scaleEffect(glow ? 1.18 : 0.92)
                    .opacity(glow ? 0.9 : 0.5)
                Circle().fill(Color.accentGradient).frame(width: 50, height: 50)
                Image(systemName: game.avatarSymbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: game.level)
            }
            .onAppear {
                guard !reduceMotion else { return }
                // 3 pulsations puis halo stable — pas de boucle infinie (batterie).
                withAnimation(.easeInOut(duration: 2.2).repeatCount(3, autoreverses: true)) { glow = true }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Niveau \(game.level)")
                        .font(.subheadline.weight(.bold))
                        .contentTransition(.numericText())
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "star.circle.fill").foregroundStyle(Color.steadyFlame)
                        Text("\(game.coins)")
                            .font(.caption.weight(.bold))
                            .contentTransition(.numericText())
                        Image(systemName: "bag.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("\(game.coins) pièces, ouvrir la boutique")
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.brandAccent.opacity(0.15))
                        Capsule().fill(Color.accentGradient).frame(width: max(8, geo.size.width * game.progress))
                    }
                }
                .frame(height: 8)

                Text("\(game.xpInLevel)/\(game.xpForNextLevel) XP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .steadyCard()
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: game.xp)
    }
}
