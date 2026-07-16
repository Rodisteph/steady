import HealthKit
import SwiftUI

/// Métriques Santé qu'une habitude peut suivre pour se valider automatiquement.
enum HealthMetric: String, CaseIterable, Identifiable {
    case water
    case mindful
    case steps
    case distance      // marche + course, en km
    case exercise      // minutes d'exercice (anneau Activité)
    case energy        // calories actives brûlées

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .water: return "Eau"
        case .mindful: return "Méditation"
        case .steps: return "Pas"
        case .distance: return "Distance (course/marche)"
        case .exercise: return "Minutes d'exercice"
        case .energy: return "Calories actives"
        }
    }

    /// Version `String` (pour l'interpolation dans du texte — évite d'afficher le code brut).
    var titleText: String {
        switch self {
        case .water: return L("Eau")
        case .mindful: return L("Méditation")
        case .steps: return L("Pas")
        case .distance: return L("Distance (course/marche)")
        case .exercise: return L("Minutes d'exercice")
        case .energy: return L("Calories actives")
        }
    }

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .mindful: return "brain.head.profile"
        case .steps: return "figure.walk"
        case .distance: return "figure.run"
        case .exercise: return "figure.strengthtraining.traditional"
        case .energy: return "flame.fill"
        }
    }

    /// Suggestion de métrique d'après le nom de l'habitude (auto-détection).
    /// Ex. « Courir » → distance, « Boire de l'eau » → eau.
    static func suggestion(forName name: String) -> HealthMetric? {
        let n = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        func has(_ words: [String]) -> Bool { words.contains { n.contains($0) } }
        if has(["courir", "course", "run", "jog", "footing", "correr"]) { return .distance }
        if has(["marche", "marcher", "walk", "pas ", "10000", "10 000", "steps", "caminar"]) { return .steps }
        if has(["eau", "boire", "water", "hydrat", "agua"]) { return .water }
        if has(["medit", "meditat", "pleine conscience", "calme", "respir", "breath"]) { return .mindful }
        if has(["sport", "muscu", "gym", "workout", "exercice", "entrainement", "fitness", "gainage", "hiit"]) { return .exercise }
        if has(["velo", "cardio", "calorie", "brancard"]) { return .energy }
        return nil
    }

    /// Seuil à atteindre aujourd'hui pour valider l'habitude (selon l'objectif réglé).
    func target(forGoal goal: Int) -> Double {
        let g = max(goal, 1)
        switch self {
        case .water: return Double(g)                          // verres (≈ 250 mL)
        case .mindful: return Double(g)                        // minutes
        case .steps: return goal > 1 ? Double(goal) * 1000 : 6000  // pas
        case .distance: return goal > 1 ? Double(goal) : 3     // km (défaut 3 km)
        case .exercise: return goal > 1 ? Double(goal) : 20    // min (défaut 20)
        case .energy: return goal > 1 ? Double(goal) * 100 : 300  // kcal (défaut 300)
        }
    }
}

@MainActor
@Observable
final class HealthManager {
    static let shared = HealthManager()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {}

    private func readTypes() -> Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let w = HKObjectType.quantityType(forIdentifier: .dietaryWater) { types.insert(w) }
        if let m = HKObjectType.categoryType(forIdentifier: .mindfulSession) { types.insert(m) }
        if let s = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(s) }
        if let d = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(d) }
        if let e = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(e) }
        if let c = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(c) }
        return types
    }

    /// Demande l'accès en lecture. Échoue proprement si la capacité HealthKit
    /// n'est pas encore activée dans le projet (renvoie `false`).
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes())
            return true
        } catch {
            return false
        }
    }

    /// Valeur du jour : verres (eau), minutes (méditation), nombre de pas.
    func todayValue(for metric: HealthMetric) async -> Double {
        await value(for: metric, since: Calendar.current.startOfDay(for: Date()))
    }

    /// Valeur cumulée d'une métrique depuis `start` jusqu'à maintenant.
    /// Sert aux défis (« 100 km ce mois » = distance cumulée depuis le début du défi).
    func value(for metric: HealthMetric, since start: Date) async -> Double {
        guard isAvailable else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        switch metric {
        case .water:
            let ml = await sum(.dietaryWater, unit: HKUnit.literUnit(with: .milli), predicate: predicate)
            return ml / 250.0                     // 1 verre ≈ 250 mL
        case .steps:
            return await sum(.stepCount, unit: .count(), predicate: predicate)
        case .mindful:
            return await mindfulMinutes(predicate: predicate)
        case .distance:
            return await sum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), predicate: predicate)  // km
        case .exercise:
            return await sum(.appleExerciseTime, unit: .minute(), predicate: predicate)                     // minutes
        case .energy:
            return await sum(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)               // kcal
        }
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func mindfulMinutes(predicate: NSPredicate) async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let minutes = (samples ?? []).reduce(0.0) { acc, sample in
                    acc + sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                }
                continuation.resume(returning: minutes)
            }
            store.execute(query)
        }
    }
}
