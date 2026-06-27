import SwiftUI

// MARK: - Design System (Steady)
//
// Palette « calme » centrée sur un vert sauge. Toutes les couleurs sont
// adaptatives (clair / sombre) afin d'offrir un rendu premium et cohérent.

extension Color {

    // MARK: Surfaces

    /// Fond principal de l'app — crème chaud en clair, anthracite en sombre.
    static var steadyBackground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.08, blue: 0.08, alpha: 1.0)
                : UIColor(red: 0.980, green: 0.976, blue: 0.965, alpha: 1.0)
        })
    }

    /// Surface des cartes — blanc pur en clair (pour se détacher du crème), gris foncé en sombre.
    static var steadyCard: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.13, green: 0.14, blue: 0.14, alpha: 1.0)
                : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        })
    }

    /// Surface secondaire (champs, chips inactives).
    static var steadySurface: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.19, blue: 0.19, alpha: 1.0)
                : UIColor(red: 0.945, green: 0.945, blue: 0.93, alpha: 1.0)
        })
    }

    // MARK: Marque

    /// Vert sauge de marque.
    static let steadySage = Color(red: 141/255, green: 163/255, blue: 153/255)

    /// Sauge profond — meilleur contraste pour texte/accents sur fond clair.
    static var steadySageDeep: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.60, green: 0.71, blue: 0.66, alpha: 1.0)
                : UIColor(red: 0.34, green: 0.46, blue: 0.40, alpha: 1.0)
        })
    }

    /// Accent chaud pour les streaks (flamme).
    static let steadyFlame = Color(red: 232/255, green: 150/255, blue: 61/255)

    // MARK: Dégradés

    /// Dégradé de marque (cartes validées, hero Premium, anneau).
    static var steadySageGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.62, green: 0.72, blue: 0.67),
                Color(red: 0.47, green: 0.60, blue: 0.54)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Dégradé chaud pour la flamme de streak.
    static var steadyFlameGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.96, green: 0.72, blue: 0.35), Color(red: 0.90, green: 0.49, blue: 0.27)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
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

/// Carte « surélevée » : surface + coins arrondis + ombre douce adaptative.
struct SteadyCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.steadyCard)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// Applique le style de carte surélevée du design system.
    func steadyCard(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(SteadyCardModifier(cornerRadius: cornerRadius))
    }
}
