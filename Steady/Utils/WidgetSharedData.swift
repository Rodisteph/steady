import Foundation

/// Instantané léger partagé entre l'app et le widget via l'App Group.
/// (Le même fichier est dupliqué côté widget — modules séparés : garder les deux identiques.)
struct SteadyWidgetSnapshot: Codable {
    var completed: Int
    var total: Int
    var weeklyTotal: Int
    var bestStreak: Int
    var habits: [Item]
    /// Dégradé du thème choisi dans l'app (hex "RRGGBB") — le widget suit la couleur de l'app.
    var gradientTop: String
    var gradientBottom: String

    struct Item: Codable, Hashable {
        var id: String
        var name: String
        var icon: String
        var done: Bool

        init(id: String = "", name: String, icon: String, done: Bool) {
            self.id = id
            self.name = name
            self.icon = icon
            self.done = done
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "circle"
            done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        }
    }

    init(completed: Int, total: Int, weeklyTotal: Int = 0, bestStreak: Int = 0, habits: [Item],
         gradientTop: String = "8FB0A1", gradientBottom: String = "5E8275") {
        self.completed = completed
        self.total = total
        self.weeklyTotal = weeklyTotal
        self.bestStreak = bestStreak
        self.habits = habits
        self.gradientTop = gradientTop
        self.gradientBottom = gradientBottom
    }

    /// Décodage tolérant : un ancien instantané (sans les nouveaux champs) reste lisible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completed = try c.decodeIfPresent(Int.self, forKey: .completed) ?? 0
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        weeklyTotal = try c.decodeIfPresent(Int.self, forKey: .weeklyTotal) ?? 0
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        habits = try c.decodeIfPresent([Item].self, forKey: .habits) ?? []
        gradientTop = try c.decodeIfPresent(String.self, forKey: .gradientTop) ?? "8FB0A1"
        gradientBottom = try c.decodeIfPresent(String.self, forKey: .gradientBottom) ?? "5E8275"
    }

    static let empty = SteadyWidgetSnapshot(completed: 0, total: 0, habits: [])
}

enum SteadyWidgetStore {
    static let appGroup = "group.Rodrigo.Steady"
    static let key = "steady_widget_snapshot"
    static let pendingKey = "steady_widget_pending_toggles"

    static func save(_ snapshot: SteadyWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let defaults = UserDefaults(suiteName: appGroup) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> SteadyWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(SteadyWidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    // MARK: - Widget interactif (cocher depuis l'écran d'accueil)

    /// Bascule optimiste dans l'instantané (retour visuel immédiat sur le widget).
    static func toggleInSnapshot(_ id: String) {
        var snap = load()
        guard let idx = snap.habits.firstIndex(where: { $0.id == id }) else { return }
        snap.habits[idx].done.toggle()
        snap.completed = snap.habits.filter { $0.done }.count
        save(snap)
    }

    /// File d'attente : l'app appliquera ces bascules à SwiftData à sa prochaine ouverture.
    static func queueToggle(_ id: String) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        var pending = defaults.stringArray(forKey: pendingKey) ?? []
        pending.append(id)
        defaults.set(pending, forKey: pendingKey)
    }

    static func pendingToggles() -> [String] {
        UserDefaults(suiteName: appGroup)?.stringArray(forKey: pendingKey) ?? []
    }

    static func clearPending() {
        UserDefaults(suiteName: appGroup)?.removeObject(forKey: pendingKey)
    }
}
