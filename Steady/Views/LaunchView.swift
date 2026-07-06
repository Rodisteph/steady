import SwiftUI

/// Racine de l'app : affiche une courte animation de lancement, puis révèle le contenu.
struct RootView: View {
    @State private var showLaunch = true

    var body: some View {
        ZStack {
            ContentView()

            if showLaunch {
                LaunchView()
                    .transition(.opacity.combined(with: .scale(scale: 1.06)))
                    .zIndex(1)
            }
        }
        .task {
            // Laisse l'animation se jouer, puis on s'efface en douceur.
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeInOut(duration: 0.45)) {
                showLaunch = false
            }
        }
    }
}

/// L'écran de lancement animé (logo qui apparaît en douceur).
struct LaunchView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.accentGradient)
                        .frame(width: 110, height: 110)
                        .shadow(color: Color.brandAccent.opacity(0.4), radius: 20, y: 10)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(animate ? 1 : 0.6)
                .opacity(animate ? 1 : 0)

                Text("Steady")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) {
                animate = true
            }
        }
    }
}

#Preview {
    LaunchView()
}
