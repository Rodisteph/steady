import SwiftUI
import Observation

/// Fournit le catalogue de routines (on-device). Pourrait devenir distant plus tard.
@Observable
final class RoutineStore {
    let routines: [RoutineTemplate] = RoutineCatalog.all

    func routines(in category: RoutineCategory) -> [RoutineTemplate] {
        routines.filter { $0.category == category }
    }

    /// Catégories réellement présentes dans le catalogue.
    var categories: [RoutineCategory] {
        RoutineCategory.allCases.filter { category in routines.contains { $0.category == category } }
    }
}
