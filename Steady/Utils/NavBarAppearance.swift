import UIKit

/// Style « premium » des titres de page (barre de navigation), appliqué globalement.
/// - Police **arrondie et lourde** avec un léger espacement des lettres.
/// - Fond **transparent** en haut (le dégradé animé transparaît derrière le grand titre),
///   et flou discret quand on fait défiler (lisibilité conservée).
@MainActor
enum NavBarAppearance {

    static func configure() {
        let large = roundedFont(size: 34, weight: .heavy)
        let inline = roundedFont(size: 17, weight: .bold)
        let color = UIColor.label

        let largeAttrs: [NSAttributedString.Key: Any] = [.font: large, .foregroundColor: color, .kern: 0.4]
        let inlineAttrs: [NSAttributedString.Key: Any] = [.font: inline, .foregroundColor: color, .kern: 0.3]

        // En haut de page (grand titre) : transparent → le fond animé se voit.
        let top = UINavigationBarAppearance()
        top.configureWithTransparentBackground()
        top.largeTitleTextAttributes = largeAttrs
        top.titleTextAttributes = inlineAttrs

        // Pendant le défilement : flou discret pour rester lisible.
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.largeTitleTextAttributes = largeAttrs
        scrolled.titleTextAttributes = inlineAttrs

        let bar = UINavigationBar.appearance()
        bar.scrollEdgeAppearance = top
        bar.standardAppearance = scrolled
        bar.compactAppearance = scrolled
    }

    /// Police système arrondie (comme le reste de l'app), dans la graisse voulue.
    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
