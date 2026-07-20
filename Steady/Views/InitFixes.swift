import SwiftUI

// MARK: - Initialiseurs publics (corrige « initializer is inaccessible due to 'private' »)
//
// En Swift, dès qu'une struct possède une propriété `private`, son initialiseur
// automatique (« memberwise ») devient privé — et les autres fichiers ne peuvent
// alors plus construire la vue. Plusieurs vues ici utilisent le motif
// `private var manager = Manager.shared`, ce qui déclenche exactement ce cas.
//
// On redonne à chaque vue concernée une « porte d'entrée » interne explicite,
// SANS toucher au reste de leur code. Écrire ces init dans une *extension*
// (plutôt que dans la struct d'origine) préserve l'initialiseur memberwise
// existant — c'est le motif recommandé par Swift.
//
// Note : les propriétés @State / @Query / @Environment ont toutes une valeur
// par défaut, donc chaque init n'a besoin d'affecter que la propriété passée.

extension MainView {
    init(store: HabitStore) {
        self.store = store
    }
}

extension IconPickerView {
    init(selection: Binding<String>) {
        self._selection = selection
    }
}

extension AvatarShopView {
    init(isPremium: Bool = false) {
        self.isPremium = isPremium
    }
}
