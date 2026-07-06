import SwiftUI

/// Un conseil/insight produit par le coach (on-device).
struct Insight: Identifiable {
    enum Kind {
        case streak
        case positive
        case warning
        case tip

        var icon: String {
            switch self {
            case .streak: return "flame.fill"
            case .positive: return "checkmark.seal.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .tip: return "lightbulb.fill"
            }
        }

        var tint: Color {
            switch self {
            case .streak: return .steadyFlame
            case .positive: return .accentDeep
            case .warning: return .orange
            case .tip: return .accentDeep
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let title: LocalizedStringKey
    /// Message déjà localisé (peut contenir des valeurs dynamiques).
    let message: String
}
