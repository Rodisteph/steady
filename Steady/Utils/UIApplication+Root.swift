import UIKit

extension UIApplication {
    /// La fenêtre active de la scène au premier plan — là où AdMob (SDK UIKit
    /// sous le capot) présente sa vidéo et où l'UMP affiche son formulaire.
    static var rootViewController: UIViewController? {
        shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?.rootViewController
    }
}
