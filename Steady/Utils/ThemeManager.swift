import SwiftUI

/// Gère la palette d'brandAccent de l'app (fonctionnalité Premium).
/// L'brandAccent (boutons, cartes validées, anneau, tint) suit la palette choisie ;
/// les fonds/surfaces restent neutres.
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    enum Palette: String, CaseIterable, Identifiable {
        case sage, ocean, sunset, lavender, rose, forest, darkGold, minimalWhite, cyberNeon, matcha, mocha, midnight
        var id: String { rawValue }

        var displayName: LocalizedStringKey {
            switch self {
            case .sage: return "Sauge"
            case .ocean: return "Océan"
            case .sunset: return "Coucher de soleil"
            case .lavender: return "Lavande"
            case .rose: return "Rose"
            case .forest: return "Forêt"
            case .darkGold: return "Or sombre"
            case .minimalWhite: return "Minimal"
            case .cyberNeon: return "Cyber Néon"
            case .matcha: return "Matcha"
            case .mocha: return "Mocha"
            case .midnight: return "Minuit"
            }
        }

        /// Couleur d'brandAccent de base.
        var base: Color {
            switch self {
            case .sage: return Color(red: 141/255, green: 163/255, blue: 153/255)
            case .ocean: return Color(red: 0.36, green: 0.58, blue: 0.69)
            case .sunset: return Color(red: 0.88, green: 0.57, blue: 0.37)
            case .lavender: return Color(red: 0.61, green: 0.56, blue: 0.77)
            case .rose: return Color(red: 0.82, green: 0.48, blue: 0.56)
            case .forest: return Color(red: 0.32, green: 0.52, blue: 0.36)
            case .darkGold: return Color(red: 0.80, green: 0.64, blue: 0.32)
            case .minimalWhite: return Color(red: 0.46, green: 0.46, blue: 0.48)
            case .cyberNeon: return Color(red: 0.32, green: 0.78, blue: 0.85)
            case .matcha: return Color(red: 0.60, green: 0.68, blue: 0.44)
            case .mocha: return Color(red: 0.64, green: 0.47, blue: 0.39)
            case .midnight: return Color(red: 0.38, green: 0.41, blue: 0.62)
            }
        }

        /// Variante profonde (texte/accents/tint), bon contraste sur fond clair.
        var deep: Color {
            switch self {
            case .sage: return Color(red: 0.34, green: 0.46, blue: 0.40)
            case .ocean: return Color(red: 0.18, green: 0.35, blue: 0.47)
            case .sunset: return Color(red: 0.70, green: 0.36, blue: 0.18)
            case .lavender: return Color(red: 0.37, green: 0.31, blue: 0.56)
            case .rose: return Color(red: 0.62, green: 0.26, blue: 0.34)
            case .forest: return Color(red: 0.16, green: 0.34, blue: 0.22)
            case .darkGold: return Color(red: 0.52, green: 0.40, blue: 0.12)
            case .minimalWhite: return Color(red: 0.22, green: 0.22, blue: 0.24)
            case .cyberNeon: return Color(red: 0.12, green: 0.44, blue: 0.62)
            case .matcha: return Color(red: 0.35, green: 0.44, blue: 0.20)
            case .mocha: return Color(red: 0.42, green: 0.28, blue: 0.21)
            case .midnight: return Color(red: 0.21, green: 0.23, blue: 0.44)
            }
        }

        private var gradientColors: [Color] {
            switch self {
            case .sage:
                return [Color(red: 0.62, green: 0.72, blue: 0.67), Color(red: 0.47, green: 0.60, blue: 0.54)]
            case .ocean:
                return [Color(red: 0.45, green: 0.66, blue: 0.77), Color(red: 0.28, green: 0.47, blue: 0.60)]
            case .sunset:
                return [Color(red: 0.95, green: 0.64, blue: 0.42), Color(red: 0.84, green: 0.44, blue: 0.30)]
            case .lavender:
                return [Color(red: 0.68, green: 0.62, blue: 0.83), Color(red: 0.50, green: 0.43, blue: 0.69)]
            case .rose:
                return [Color(red: 0.87, green: 0.58, blue: 0.66), Color(red: 0.72, green: 0.38, blue: 0.47)]
            case .forest:
                return [Color(red: 0.34, green: 0.55, blue: 0.38), Color(red: 0.18, green: 0.38, blue: 0.24)]
            case .darkGold:
                return [Color(red: 0.88, green: 0.74, blue: 0.42), Color(red: 0.62, green: 0.47, blue: 0.16)]
            case .minimalWhite:
                return [Color(red: 0.56, green: 0.56, blue: 0.59), Color(red: 0.30, green: 0.30, blue: 0.33)]
            case .cyberNeon:
                return [Color(red: 0.30, green: 0.85, blue: 0.86), Color(red: 0.55, green: 0.30, blue: 0.88)]
            case .matcha:
                return [Color(red: 0.72, green: 0.78, blue: 0.56), Color(red: 0.48, green: 0.58, blue: 0.32)]
            case .mocha:
                return [Color(red: 0.76, green: 0.60, blue: 0.50), Color(red: 0.52, green: 0.36, blue: 0.28)]
            case .midnight:
                return [Color(red: 0.46, green: 0.49, blue: 0.72), Color(red: 0.25, green: 0.27, blue: 0.50)]
            }
        }

        var gradient: LinearGradient {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    nonisolated static var persistedPalette: Palette {
        let raw = UserDefaults.standard.string(forKey: "app_palette") ?? Palette.sage.rawValue
        return Palette(rawValue: raw) ?? .sage
    }

    var palette: Palette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: "app_palette") }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "app_palette") ?? Palette.sage.rawValue
        palette = Palette(rawValue: raw) ?? .sage
    }
}
