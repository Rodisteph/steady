import SwiftUI

// MARK: - Design System (Steady)
//
// Palette « calme » centrée sur un vert sauge. Toutes les couleurs sont
// adaptatives (clair / sombre) afin d'offrir un rendu premium et cohérent.

extension Color {

    // MARK: Surfaces
    //
    // Les couleurs adaptatives (clair / sombre) sont définies dans le catalogue
    // d'assets : `SteadyBackground`, `SteadyCard`, `SteadySurface`, `SteadySageDeep`.
    // Xcode génère automatiquement les symboles `Color.steadyBackground`, etc.
    //
    // Important : on N'UTILISE PAS `Color(UIColor { trait in … })` — la résolution
    // d'un UIColor dynamique peut se produire hors du thread principal pendant le
    // rendu SwiftUI (AsyncRenderer) et provoquer un crash sur appareil
    // (`_dispatch_assert_queue_fail`). Les couleurs nommées du catalogue sont
    // résolues de façon thread-safe par SwiftUI.

    // MARK: Accent (thème Premium)
    //
    // L'brandAccent suit la palette choisie via `ThemeManager` (Premium). Ces
    // propriétés peuvent être évaluées par SwiftUI hors du main thread pendant le
    // rendu, donc elles lisent uniquement la palette persistée thread-safe.

    /// Couleur d'brandAccent de base (palette courante).
    static var brandAccent: Color { ThemeManager.persistedPalette.base }

    /// Variante profonde de l'brandAccent (texte, tint, icônes).
    static var accentDeep: Color { ThemeManager.persistedPalette.deep }

    /// Dégradé d'brandAccent (cartes validées, boutons, anneau, hero Premium).
    static var accentGradient: LinearGradient { ThemeManager.persistedPalette.gradient }

    /// Accent chaud pour les streaks (flamme) — indépendant du thème.
    static let steadyFlame = Color(red: 232/255, green: 150/255, blue: 61/255)
}

// MARK: - Tokens d'espacement & de forme

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
        static let pill: CGFloat = 100
    }
}

// MARK: - Modifiers réutilisables

/// Carte « surélevée » premium : surface + glassmorphism léger (voile lumineux +
/// liseré « verre »), coins continus harmonisés, et ombres naturelles en deux
/// couches (contact + ambiante).
struct SteadyCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.steadyCard)

                    // Voile lumineux subtil (haut → centre) : effet « verre ».
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                // Liseré fin façon bord de verre (clair en haut, fondu en bas).
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
            // Ombre de contact (proche) + ombre ambiante (large) = profondeur naturelle.
            .shadow(color: Color.black.opacity(0.05), radius: 1.5, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

extension View {
    /// Applique le style de carte surélevée du design system.
    func steadyCard(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(SteadyCardModifier(cornerRadius: cornerRadius))
    }
}
