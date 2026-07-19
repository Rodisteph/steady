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
    var kind: LeaderboardKind = .completed   // seul classement affiché : les validations

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
        // Demande la permission d'afficher les notifications + publie le jeton push.
        // Indispensable pour recevoir les push de messages de groupe.
        PushNotificationService.shared.requestPermissionAndSync()
        await service.syncMyProfile(myProfile)
        // Avant de charger les groupes : garantit qu'un nouvel arrivant en a un.
        await service.ensureWelcomeGroup()
        friends = await service.friends()
        requests = await service.incomingRequests()
        groups = await service.groups()
        cheers = await service.receivedCheers()
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
                searchMessage = L("Personne trouvé. Vérifie l'orthographe : ton ami doit avoir ouvert l'onglet Communauté connecté au moins une fois.")
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

    /// Encouragements reçus, affichés en haut de l'onglet Amis.
    var cheers: [Cheer] = []

    /// Marque les encouragements comme vus : on vide la boîte serveur et l'écran.
    func clearCheers() async {
        await service.clearCheers()
        cheers = []
    }
    func deleteMyData() async { await service.deleteMyAccountData() }

    /// Crée un groupe et recharge la liste. Renvoie `false` en cas d'échec (réseau…).
    func createGroup(name: String, icon: String, friends: [UserProfile]) async -> Bool {
        do {
            try await service.createGroup(name: name, icon: icon, friends: friends)
            groups = await service.groups()
            return true
        } catch {
            return false
        }
    }

    func members(_ g: SocialGroup) async -> [UserProfile] { await service.members(of: g) }

    /// Ajoute des amis à un groupe existant. Renvoie `false` en cas d'échec.
    func addMembers(_ friendsToAdd: [UserProfile], to g: SocialGroup) async -> Bool {
        guard !friendsToAdd.isEmpty else { return false }
        do {
            try await service.addMembers(friendsToAdd, to: g)
            groups = await service.groups()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Messages non lus

    /// Compteur observable : incrémenté à chaque lecture pour rafraîchir les pastilles.
    private(set) var readMarker = 0

    /// Y a-t-il des messages plus récents que ma dernière ouverture de ce chat ?
    func hasUnread(_ g: SocialGroup) -> Bool {
        _ = readMarker   // dépendance @Observable : la pastille se met à jour
        guard let last = g.lastMessageAt else { return false }
        // Si le dernier message est le mien, jamais de pastille.
        if let author = g.lastMessageAuthorUID, author == AuthManager.shared.uid { return false }
        let read = UserDefaults.standard.object(forKey: "steady_group_read_\(g.id)") as? Date ?? .distantPast
        return last > read
    }

    func markRead(_ g: SocialGroup) {
        UserDefaults.standard.set(Date(), forKey: "steady_group_read_\(g.id)")
        readMarker += 1
    }

    func messages(_ g: SocialGroup) async -> [ChatMessage] { await service.messages(in: g) }
    /// Envoie un message. Renvoie `nil` si le filtre de modération le refuse
    /// (l'appelant affiche alors `ContentModeration.rejectionMessage`).
    func send(_ text: String, to g: SocialGroup) async -> [ChatMessage]? {
        guard !ContentModeration.containsObjectionable(text) else { return nil }
        await service.send(text, to: g)
        return await service.messages(in: g)
    }

    // MARK: - Modération (règle App Store 1.2)

    func report(message: ChatMessage, in group: SocialGroup, reason: ReportReason) async {
        await service.report(message: message, in: group, reason: reason)
    }

    func report(user: UserProfile, reason: ReportReason) async {
        await service.report(user: user, reason: reason)
    }

    /// Bloque un utilisateur puis rafraîchit amis et messages (il doit disparaître).
    func block(_ uid: String) async {
        await service.block(uid)
        friends = await service.friends()
    }

    func unblock(_ uid: String) async {
        await service.unblock(uid)
        friends = await service.friends()
    }

    func blockedUsers() async -> [UserProfile] {
        await service.blockedUsers()
    }
}
