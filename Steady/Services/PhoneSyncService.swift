import Foundation
import SwiftData
import WatchConnectivity

/// Donnée d'habitude échangée avec la montre (légère, encodable).
struct WatchHabitDTO: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let completed: Bool
    let streak: Int
    let dayCount: Int
    let goal: Int
}

private struct WatchReplyHandler: @unchecked Sendable {
    nonisolated(unsafe) let handler: ([String: Any]) -> Void

    nonisolated init(handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }

    func send(payload: Data) {
        handler(["payload": payload])
    }
}

/// Côté iPhone : répond aux demandes de la montre (lecture + bascule d'habitude).
/// Réutilise `HabitStore` pour ne pas dupliquer la logique métier.
final class PhoneSyncService: NSObject, WCSessionDelegate {
    static let shared = PhoneSyncService()
    private var container: ModelContainer?

    func activate(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Construction du snapshot (sur le main actor, SwiftData oblige)

    @MainActor
    private func payload(togglingID id: String? = nil) -> Data? {
        guard let container else { return nil }
        let context = ModelContext(container)
        let store = HabitStore()
        store.configure(with: context)

        let today = Date()
        guard let all = try? context.fetch(
            FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.creationDate)])
        ) else { return nil }

        if let id, let habit = all.first(where: { $0.id.uuidString == id }) {
            store.toggleHabit(habit, on: today)
        }

        let scheduled = all.filter { $0.isScheduled(on: today) }
        let dtos = scheduled.map { h in
            WatchHabitDTO(
                id: h.id.uuidString,
                name: h.name,
                icon: h.icon,
                completed: store.isCompleted(h, on: today),
                streak: store.currentStreak(for: h),
                dayCount: store.dayCount(for: h, on: today),
                goal: h.dailyGoal
            )
        }
        return try? JSONEncoder().encode(dtos)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let action = message["action"] as? String
        let id = message["id"] as? String
        let reply = WatchReplyHandler(handler: replyHandler)

        DispatchQueue.main.async {
            let data = MainActor.assumeIsolated {
                self.payload(togglingID: action == "toggle" ? id : nil) ?? Data()
            }
            reply.send(payload: data)
        }
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
