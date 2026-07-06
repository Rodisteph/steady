import SwiftUI

// MARK: - Glow pulsé (CTA premium)

/// Ombre colorée qui « respire » doucement — pour attirer l'œil sur un bouton clé.
struct PulsingGlow: ViewModifier {
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(on ? 0.55 : 0.25), radius: on ? 22 : 10, y: 7)
            .onAppear {
                guard !reduceMotion else { return }
                // 5 pulsations pour attirer l'œil, puis le glow se fige (batterie).
                withAnimation(.easeInOut(duration: 1.7).repeatCount(5, autoreverses: true)) { on = true }
            }
    }
}

// MARK: - Apparition en cascade

/// Fondu + léger glissement vers le haut, décalé selon l'index (effet « cascade »).
/// `enabled: false` = affichage direct (évite de re-fondre les lignes recyclées d'une List au scroll).
struct AppearStagger: ViewModifier {
    let index: Int
    var enabled: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                if !enabled || reduceMotion { shown = true; return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.06)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// Glow coloré qui respire (boutons premium).
    func pulsingGlow(_ color: Color = .brandAccent) -> some View {
        modifier(PulsingGlow(color: color))
    }

    /// Apparition en cascade selon la position dans une liste.
    func appearStagger(_ index: Int, enabled: Bool = true) -> some View {
        modifier(AppearStagger(index: index, enabled: enabled))
    }
}
