import SwiftUI

/// Fond doux et apaisant : des halos de couleur (du thème courant) derrière le contenu.
///
/// ⚡️ Batterie : ce fond est présent sur ~20 écrans (dont les 5 onglets, gardés
/// vivants par la TabView). L'ancienne version animait en boucle infinie 4 cercles
/// avec `blur(90)` — un flou recalculé par le GPU à CHAQUE frame, en continu.
/// Désormais : dégradés radiaux (aucun filtre de flou) + une seule animation
/// d'installation à l'apparition, puis plus rien ne bouge → coût quasi nul.
struct AnimatedBackground: View {
    /// `false` = halos figés dès l'apparition (écrans de saisie).
    var animated: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        // IMPORTANT : la base est une Color (qui prend exactement la taille proposée),
        // et les halos sont dessinés en OVERLAY. Un overlay ne peut jamais agrandir sa
        // base → le fond ne « gonfle » jamais son conteneur, même empilé en ZStack.
        // (Avant, les halos de 570 px élargissaient le ZStack et débordaient l'écran.)
        Color.steadyBackground
            .overlay {
                ZStack {
                    blob(Color.brandAccent.opacity(0.28), size: 340)
                        .offset(x: -110, y: settled ? -200 : -250)

                    blob(Color.accentDeep.opacity(0.20), size: 300)
                        .offset(x: 130, y: settled ? -30 : -70)

                    blob(Color.brandAccent.opacity(0.22), size: 380)
                        .offset(x: -70, y: settled ? 330 : 380)

                    blob(Color.accentDeep.opacity(0.16), size: 280)
                        .offset(x: 150, y: settled ? 300 : 350)
                }
            }
            .clipped()          // les halos ne dépassent pas de la zone
            .ignoresSafeArea()
            .onAppear {
                guard animated, !reduceMotion, !settled else { settled = true; return }
                // Une seule dérive douce à l'apparition — pas de boucle infinie.
                withAnimation(.easeOut(duration: 1.4)) { settled = true }
            }
    }

    /// Halo sans filtre de flou : un dégradé radial donne le même rendu
    /// pour une fraction du coût GPU.
    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: size * 0.75))
            .frame(width: size * 1.5, height: size * 1.5)
    }
}

#Preview {
    AnimatedBackground()
}
