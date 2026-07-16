import ActivityKit
import Foundation

/// Données de la Live Activity « session de révision » (écran verrouillé + Dynamic Island).
///
/// ⚠️ Ce fichier est **dupliqué à l'identique** dans `Steady/Models/` et
/// `Steadywidget/`. Les dossiers synchronisés d'Xcode rattachent chaque fichier
/// à une seule cible : l'app et l'extension ont donc chacune besoin de leur
/// copie (même motif que `WidgetSharedData.swift`). Toute modification doit
/// être reportée dans les deux, sinon le décodage échoue et la Live Activity
/// ne s'affiche jamais.
/// `nonisolated` est indispensable : le projet compile avec
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, donc la conformité à
/// `ActivityAttributes` serait isolée au main actor. Or ActivityKit décode ces
/// données depuis l'extension widget, hors du main actor.
nonisolated struct FocusActivityAttributes: ActivityAttributes {
    /// Ce qui évolue pendant la session.
    nonisolated struct ContentState: Codable, Hashable {
        /// Fin prévue de la session. On la passe à `Text(timerInterval:)` :
        /// le système décompte tout seul, sans qu'on pousse une mise à jour
        /// chaque seconde (sinon la batterie et les quotas exploseraient).
        var endDate: Date
    }

    /// Fixe pour toute la durée de la session.
    var examTitle: String
    var startDate: Date
}
