import Foundation
import WatchConnectivity

/// Donnée d'habitude reçue de l'iPhone (identique au DTO côté téléphone).
struct WatchHabitDTO: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let completed: Bool
    let streak: Int
    let dayCount: Int
    let goal: Int
}

/// Côté montre : demande la liste des habitudes à l'iPhone et envoie les bascules.
@Observable
final class WatchSyncService: NSObject, WCSessionDelegate {
    static let shared = WatchSyncService()

    var habits: [WatchHabitDTO] = []
    var reachable = false
    var loaded = false

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func refresh() { send(["action": "fetch"]) }
    func toggle(_ id: String) { send(["action": "toggle", "id": id]) }

    private func send(_ message: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            Task { @MainActor in self.reachable = false }
            return
        }
        session.sendMessage(message, replyHandler: { reply in
            guard let data = reply["payload"] as? Data,
                  let dtos = try? JSONDecoder().decode([WatchHabitDTO].self, from: data) else { return }
            Task { @MainActor in
                self.habits = dtos
                self.reachable = true
                self.loaded = true
            }
        }, errorHandler: { _ in
            Task { @MainActor in self.reachable = WCSession.default.isReachable }
        })
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.reachable = session.isReachable
            self.refresh()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.reachable = session.isReachable
            if session.isReachable { self.refresh() }
        }
    }
}
