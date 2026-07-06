import SwiftUI
import Observation

@MainActor
@Observable
final class SocialStore {
    private let service: SocialService

    var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: "steady_social_username")
            Task {
                await service.syncMyProfile(myProfile)
                await reloadLeaderboard()
            }
        }
    }
    var myStreak: Int = 0

    var friends: [UserProfile] = []
    var requests: [FriendRequest] = []
    var leaderboard: [LeaderboardEntry] = []
    var groups: [SocialGroup] = []
    var kind: LeaderboardKind = .streak

    // Recherche d'amis par pseudo.
    var searchResults: [UserProfile] = []
    var searchMessage: String?          // erreur ou « aucun résultat » à afficher
    var sentInvites: Set<String> = []   // uid déjà invités (pour le feedback « Envoyé ✓ »)

    init(service: SocialService = FirebaseSocialService()) {
        self.service = service
        self.username = UserDefaults.standard.string(forKey: "steady_social_username") ?? "Moi"
    }

    var myProfile: UserProfile {
        UserProfile(
            id: "me",
            username: username,
            avatarSymbol: GamificationManager.shared.avatarSymbol,
            level: GamificationManager.shared.level,
            score: GamificationManager.shared.xp,
            streak: myStreak
        )
    }

    func refresh() async {
        await service.syncMyProfile(myProfile)
        friends = await service.friends()
        requests = await service.incomingRequests()
        groups = await service.groups()
        await reloadLeaderboard()
    }

    func reloadLeaderboard() async {
        leaderboard = await service.leaderboard(kind: kind, me: myProfile)
    }

    func setKind(_ k: LeaderboardKind) {
        kind = k
        Task { await reloadLeaderboard() }
    }

    func search(_ term: String) async {
        searchMessage = nil
        do {
            searchResults = try await service.searchUsers(matching: term)
            if searchResults.isEmpty {
                searchMessage = L("Personne trouvé. Vérifie l'orthographe — ton ami doit avoir ouvert l'onglet Communauté connecté au moins une fois.")
            }
        } catch {
            searchResults = []
            searchMessage = error.localizedDescription
        }
    }

    func clearSearch() {
        searchResults = []
        searchMessage = nil
    }

    func invite(_ user: UserProfile) async {
        do {
            try await service.sendRequest(to: user)
            sentInvites.insert(user.id)
        } catch {
            searchMessage = error.localizedDescription
        }
    }
    func accept(_ r: FriendRequest) async {
        await service.accept(r)
        requests = await service.incomingRequests()
        friends = await service.friends()
        await reloadLeaderboard()
    }
    func decline(_ r: FriendRequest) async {
        await service.decline(r)
        requests = await service.incomingRequests()
    }
    func remove(_ f: UserProfile) async {
        await service.remove(f)
        friends = await service.friends()
        await reloadLeaderboard()
    }
    func cheer(_ f: UserProfile) async { await service.cheer(f) }
    func deleteMyData() async { await service.deleteMyAccountData() }

    func messages(_ g: SocialGroup) async -> [ChatMessage] { await service.messages(in: g) }
    func send(_ text: String, to g: SocialGroup) async -> [ChatMessage] {
        await service.send(text, to: g)
        return await service.messages(in: g)
    }
}
