import Foundation

/// Abstraction du backend social. Aujourd'hui : `MockSocialService` (local, en mémoire).
/// Demain : `FirebaseSocialService` — même interface, zéro changement d'UI.
protocol SocialService {
    /// Pousse mon profil (pseudo, avatar, niveau, série) vers le backend pour que mes amis le voient.
    func syncMyProfile(_ profile: UserProfile) async
    /// Efface toutes mes données serveur (profil, amis, demandes…). Pour la suppression de compte.
    func deleteMyAccountData() async
    func friends() async -> [UserProfile]
    func incomingRequests() async -> [FriendRequest]
    /// Cherche des profils dont le pseudo commence par `term` (insensible à la casse).
    func searchUsers(matching term: String) async throws -> [UserProfile]
    /// Envoie une demande d'ami à un profil trouvé via la recherche.
    func sendRequest(to user: UserProfile) async throws
    func accept(_ request: FriendRequest) async
    func decline(_ request: FriendRequest) async
    func remove(_ friend: UserProfile) async
    func cheer(_ friend: UserProfile) async
    func leaderboard(kind: LeaderboardKind, me: UserProfile) async -> [LeaderboardEntry]
    func groups() async -> [SocialGroup]
    /// Crée un groupe avec moi + les amis choisis comme membres.
    func createGroup(name: String, icon: String, friends: [UserProfile]) async throws
    /// Profils des membres d'un groupe (pseudo, niveau, série).
    func members(of group: SocialGroup) async -> [UserProfile]
    /// Ajoute des amis à un groupe existant.
    func addMembers(_ friends: [UserProfile], to group: SocialGroup) async throws
    func messages(in group: SocialGroup) async -> [ChatMessage]
    func send(_ text: String, to group: SocialGroup) async

    // MARK: - Modération (règle App Store 1.2)

    /// Signale un message offensant. Le contenu est copié côté serveur pour
    /// pouvoir être examiné même si l'auteur le supprime ensuite.
    func report(message: ChatMessage, in group: SocialGroup, reason: ReportReason) async
    /// Signale un utilisateur (pseudo/avatar offensant).
    func report(user: UserProfile, reason: ReportReason) async
    /// Bloque un utilisateur : ses messages et son profil disparaissent chez moi.
    func block(_ uid: String) async
    func unblock(_ uid: String) async
    /// uid que j'ai bloqués (pour filtrer messages, amis et classement).
    func blockedUIDs() async -> Set<String>
    /// Profils que j'ai bloqués (pour l'écran « Utilisateurs bloqués »).
    func blockedUsers() async -> [UserProfile]
}

enum SocialError: LocalizedError {
    case userNotFound
    case notSignedIn
    case network
    var errorDescription: String? {
        switch self {
        case .userNotFound: return String(localized: "Aucun utilisateur trouvé avec ce pseudo.")
        case .notSignedIn: return String(localized: "Connecte-toi pour utiliser la communauté.")
        case .network: return String(localized: "Connexion impossible. Vérifie ton réseau et réessaie.")
        }
    }
}

/// Implémentation locale de démo (aucun réseau). Permet de développer et tester l'UI.
@MainActor
final class MockSocialService: SocialService {
    private var _friends: [UserProfile] = [
        UserProfile(id: "u1", username: "Camille", avatarSymbol: "leaf.fill", level: 7, score: 720, streak: 14),
        UserProfile(id: "u2", username: "Léo", avatarSymbol: "flame.fill", level: 4, score: 410, streak: 6),
        UserProfile(id: "u3", username: "Sofia", avatarSymbol: "sparkles", level: 9, score: 980, streak: 21),
        UserProfile(id: "u4", username: "Tom", avatarSymbol: "bolt.fill", level: 2, score: 180, streak: 3)
    ]
    private var _requests: [FriendRequest] = [
        FriendRequest(id: "r1", from: UserProfile(id: "u5", username: "Inès", avatarSymbol: "moon.fill", level: 5, score: 520, streak: 9))
    ]
    private var _groups: [SocialGroup] = [
        SocialGroup(id: "g1", name: "Famille", icon: "house.fill", memberCount: 4),
        SocialGroup(id: "g2", name: "Running Club", icon: "figure.run", memberCount: 8)
    ]
    private var _messages: [String: [ChatMessage]] = [
        "g1": [
            ChatMessage(id: "m1", authorName: "Camille", text: "On garde le rythme cette semaine 💪", date: .now.addingTimeInterval(-7200), isMine: false),
            ChatMessage(id: "m2", authorName: "Moi", text: "Carrément, 5/5 aujourd'hui !", date: .now.addingTimeInterval(-3600), isMine: true)
        ]
    ]

    func syncMyProfile(_ profile: UserProfile) async { /* démo : no-op */ }
    func deleteMyAccountData() async { /* démo : no-op */ }
    func friends() async -> [UserProfile] { _friends }
    func incomingRequests() async -> [FriendRequest] { _requests }

    func searchUsers(matching term: String) async throws -> [UserProfile] {
        let clean = term.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty else { return [] }
        // Démo : cherche parmi des profils fictifs.
        let pool = _friends + [
            UserProfile(id: "u6", username: "Marco", avatarSymbol: "star.fill", level: 3, score: 300, streak: 5),
            UserProfile(id: "u7", username: "Marie", avatarSymbol: "heart.fill", level: 6, score: 640, streak: 12)
        ]
        return pool.filter { $0.username.lowercased().hasPrefix(clean) }
    }

    func sendRequest(to user: UserProfile) async throws {
        // Démo : on ajoute directement l'ami.
        if !_friends.contains(where: { $0.id == user.id }) { _friends.append(user) }
    }

    func accept(_ request: FriendRequest) async {
        _requests.removeAll { $0.id == request.id }
        _friends.append(request.from)
    }
    func decline(_ request: FriendRequest) async {
        _requests.removeAll { $0.id == request.id }
    }
    func remove(_ friend: UserProfile) async {
        _friends.removeAll { $0.id == friend.id }
    }
    func cheer(_ friend: UserProfile) async { /* démo : no-op */ }

    func leaderboard(kind: LeaderboardKind, me: UserProfile) async -> [LeaderboardEntry] {
        let everyone = _friends + [me]
        func value(_ p: UserProfile) -> Int {
            switch kind {
            case .streak: return p.streak
            case .completed: return p.score
            case .consistency: return min(100, p.score / 10)
            }
        }
        let sorted = everyone.sorted { value($0) > value($1) }
        return sorted.enumerated().map { idx, p in
            LeaderboardEntry(id: p.id, profile: p, rank: idx + 1, value: value(p), isMe: p.id == me.id)
        }
    }

    func groups() async -> [SocialGroup] { _groups }

    func createGroup(name: String, icon: String, friends: [UserProfile]) async throws {
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        _groups.append(SocialGroup(id: UUID().uuidString, name: clean, icon: icon,
                                   memberCount: friends.count + 1, memberIDs: friends.map(\.id)))
    }

    func members(of group: SocialGroup) async -> [UserProfile] {
        // Démo : les premiers amis fictifs.
        Array(_friends.prefix(max(1, group.memberCount)))
    }

    func addMembers(_ friends: [UserProfile], to group: SocialGroup) async throws {
        guard let idx = _groups.firstIndex(where: { $0.id == group.id }) else { return }
        let newIDs = friends.map(\.id).filter { !_groups[idx].memberIDs.contains($0) }
        _groups[idx].memberIDs.append(contentsOf: newIDs)
        _groups[idx].memberCount += newIDs.count
    }

    func messages(in group: SocialGroup) async -> [ChatMessage] {
        (_messages[group.id] ?? []).filter { !_blocked.contains($0.authorUID) }
    }
    func send(_ text: String, to group: SocialGroup) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        _messages[group.id, default: []].append(
            ChatMessage(id: UUID().uuidString, authorName: "Moi", text: clean, date: .now, isMine: true, authorUID: "me")
        )
    }

    // MARK: - Modération (démo : en mémoire)

    private var _blocked: Set<String> = []

    func report(message: ChatMessage, in group: SocialGroup, reason: ReportReason) async {
        print("📣 [démo] message signalé : \(message.id) — \(reason.rawValue)")
    }
    func report(user: UserProfile, reason: ReportReason) async {
        print("📣 [démo] utilisateur signalé : \(user.username) — \(reason.rawValue)")
    }
    func block(_ uid: String) async { _blocked.insert(uid) }
    func unblock(_ uid: String) async { _blocked.remove(uid) }
    func blockedUIDs() async -> Set<String> { _blocked }
    func blockedUsers() async -> [UserProfile] { _friends.filter { _blocked.contains($0.id) } }
}
