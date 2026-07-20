import SwiftUI

// MARK: - Initialiseurs publics (corrige « initializer is inaccessible due to 'private' »)
//
// En Swift, dès qu'une struct possède une propriété `private` avec valeur par
// défaut (ex. `private var manager = Manager.shared`, ou un @State/@Query/@Environment
// privé), son initialiseur automatique (« memberwise ») devient privé — et les
// autres fichiers ne peuvent alors plus construire la vue.
//
// On redonne ici une « porte d'entrée » interne explicite aux vues concernées,
// dans une extension, SANS toucher au reste de leur code.
//
// ⚠️ Ce fichier ne peut traiter QUE les vues dont la propriété passée est un
// stockage accessible (ex. `var store`, `var isPremium`). Pour une vue avec un
// @Binding, le stockage `_selection` est privé et n'est visible que dans le
// fichier de la vue : son init est donc placé directement dans ce fichier-là
// (voir IconPickerView.swift).

extension MainView {
    init(store: HabitStore) {
        self.store = store
    }
}

extension AvatarShopView {
    init(isPremium: Bool = false) {
        self.isPremium = isPremium
    }
}
