import Foundation

/// Mémorise les jours « bienveillance » (repos). Un jour de repos est traité comme
/// un jour non prévu dans les calculs de série : il ne casse JAMAIS un streak.
enum RestDayStore {
    private static let key = "steady_rest_dates"

    /// Cache mémoire : les calculs de série appellent `contains` pour chaque jour
    /// testé (des centaines de fois par habitude) — on ne relit le disque qu'une fois.
    private static var cache: Set<Date>?

    static func add(_ day: Date) {
        let start = Calendar.current.startOfDay(for: day)
        var dates = all()
        dates.insert(start)
        save(dates)
    }

    static func remove(_ day: Date) {
        let start = Calendar.current.startOfDay(for: day)
        var dates = all()
        dates.remove(start)
        save(dates)
    }

    static func contains(_ day: Date) -> Bool {
        all().contains(Calendar.current.startOfDay(for: day))
    }

    private static func all() -> Set<Date> {
        if let cache { return cache }
        let stamps = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        let loaded = Set(stamps.map { Date(timeIntervalSince1970: $0) })
        cache = loaded
        return loaded
    }

    private static func save(_ dates: Set<Date>) {
        cache = dates
        UserDefaults.standard.set(dates.map { $0.timeIntervalSince1970 }, forKey: key)
    }
}
