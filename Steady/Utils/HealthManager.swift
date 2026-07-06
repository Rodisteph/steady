import HealthKit
import SwiftUI

/// Métriques Santé qu'une habitude peut suivre pour se valider automatiquement.
enum HealthMetric: String, CaseIterable, Identifiable {
    case water
    case mindful
    case steps

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .water: return "Eau"
        case .mindful: return "Méditation"
        case .steps: return "Pas"
        }
    }

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .mindful: return "brain.head.profile"
        case .steps: return "figure.walk"
        }
    }

    /// Seuil à atteindre aujourd'hui pour valider l'habitude (selon l'objectif réglé).
    func target(forGoal goal: Int) -> Double {
        switch self {
        case .water: return Double(max(goal, 1))               // verres (≈ 250 mL)
        case .mindful: return Double(max(goal, 1))             // minutes
        case .steps: return goal > 1 ? Double(goal) * 1000 : 6000  // pas
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
        guard isAvailable else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        switch metric {
        case .water:
            let ml = await sum(.dietaryWater, unit: HKUnit.literUnit(with: .milli), predicate: predicate)
            return ml / 250.0                     // 1 verre ≈ 250 mL
        case .steps:
            return await sum(.stepCount, unit: .count(), predicate: predicate)
        case .mindful:
            return await mindfulMinutes(predicate: predicate)
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
