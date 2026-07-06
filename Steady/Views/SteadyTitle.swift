import SwiftUI

/// Grand titre de page « signature » : police arrondie lourde, remplie du dégradé
/// du thème, avec une apparition animée. Remplace le titre natif de la barre.
struct SteadyTitle: View {
    let text: LocalizedStringKey
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .kerning(0.4)
            .foregroundStyle(Color.accentGradient)
            .shadow(color: Color.brandAccent.opacity(0.25), radius: 6, y: 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.sm)
            .opacity(appear ? 1 : 0)
            .offset(y: appear || reduceMotion ? 0 : 14)
            .onAppear {
                guard !reduceMotion else { appear = true; return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appear = true }
            }
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack {
        SteadyTitle("Progrès")
        Spacer()
    }
    .background(AnimatedBackground())
}
