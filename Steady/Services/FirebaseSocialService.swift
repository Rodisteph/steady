import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Implémentation réelle du social via Firebase Firestore.
/// Modèle de données :
///   users/{uid}                      → profil public (pseudo, avatar, niveau, série…)
///   users/{uid}/friends/{friendUid}  → arête d'amitié (stockée des deux côtés)
///   users/{uid}/requests/{fromUid}   → demande d'ami reçue
///   groups/{groupId}                 → groupe { name, icon, members:[uid] }
///   groups/{groupId}/messages/{id}   → messages du groupe
@MainActor
final class FirebaseSocialService: SocialService {
    private let db = Firestore.firestore()

    private var myUID: String? { Auth.auth().currentUser?.uid }

    // MARK: - Profil

    func syncMyProfile(_ profile: UserProfile) async {
        guard let uid = myUID else { return }
        let data: [String: Any] = [
            "username": profile.username,
            "usernameLower": profile.username.lowercased(),
            "avatar": profile.avatarSymbol,
            "level": profile.level,
            "score": profile.score,
            "streak": profile.streak,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try? await db.collection("users").document(uid).setData(data, merge: true)
    }

    func deleteMyAccountData() async {
        guard let uid = myUID else { return }
        let userRef = db.collection("users").document(uid)

        // Retirer les arêtes d'amitié des deux côtés.
        if let friendsSnap = try? await userRef.collection("friends").getDocuments() {
            for doc in friendsSnap.documents {
                let friendUID = doc.documentID
                try? await db.collection("users").document(friendUID)
                    .collection("friends").document(uid).delete()
                try? await userRef.collection("friends").document(friendUID).delete()
            }
        }
        // Supprimer mes demandes reçues et mes encouragements.
        for sub in ["requests", "cheers"] {
            if let snap = try? await userRef.collection(sub).getDocuments() {
                for doc in snap.documents { try? await doc.reference.delete() }
            }
        }
        // Supprimer mon profil public.
        try? await userRef.delete()
    }

    private func profile(id: String, data: [String: Any]) -> UserProfile {
        UserProfile(
            id: id,
            username: data["username"] as? String ?? "?",
            avatarSymbol: data["avatar"] as? String ?? "person.fill",
            level: data["level"] as? Int ?? 1,
            score: data["score"] as? Int ?? 0,
            streak: data["streak"] as? Int ?? 0
        )
    }

    private func fetchProfile(_ uid: String) async -> UserProfile? {
        guard let snap = try? await db.collection("users").document(uid).getDocument(),
              let data = snap.data() else { return nil }
        return profile(id: uid, data: data)
    }

    // MARK: - Amis

    func friends() async -> [UserProfile] {
        guard let uid = myUID,
              let snap = try? await db.collection("users").document(uid).collection("friends").getDocuments()
        else { return [] }
        let blocked = await blockedUIDs()
        var result: [UserProfile] = []
        for doc in snap.documents where !blocked.contains(doc.documentID) {
            if let p = await fetchProfile(doc.documentID) { result.append(p) }
        }
        return result.sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
    }

    func incomingRequests() async -> [FriendRequest] {
        guard let uid = myUID,
              let snap = try? await db.collection("users").document(uid).collection("requests").getDocuments()
        else { return [] }
        return snap.documents.map { doc in
            let d = doc.data()
            return FriendRequest(
                id: doc.documentID,
                from: UserProfile(
                    id: doc.documentID,
                    username: d["fromUsername"] as? String ?? "?",
                    avatarSymbol: d["fromAvatar"] as? String ?? "person.fill",
                    level: d["fromLevel"] as? Int ?? 1,
                    score: d["fromScore"] as? Int ?? 0,
                    streak: d["fromStreak"] as? Int ?? 0
                )
            )
        }
    }

    func searchUsers(matching term: String) async throws -> [UserProfile] {
        guard let uid = myUID else { throw SocialError.notSignedIn }
        let clean = term.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty else { return [] }

        // Recherche par préfixe : tous les pseudos qui commencent par `clean`.
        // (\u{f8ff} est le plus grand caractère Unicode → borne haute de l'intervalle.)
        do {
            let snap = try await db.collection("users")
                .whereField("usernameLower", isGreaterThanOrEqualTo: clean)
                .whereField("usernameLower", isLessThan: clean + "\u{f8ff}")
                .limit(to: 15)
                .getDocuments()
            return snap.documents
                .filter { $0.documentID != uid }
                .map { profile(id: $0.documentID, data: $0.data()) }
        } catch {
            print("⚠️ Recherche de pseudo échouée : \(error.localizedDescription)")
            throw SocialError.network
        }
    }

    func sendRequest(to user: UserProfile) async throws {
        guard let uid = myUID else { throw SocialError.notSignedIn }
        let me = await fetchProfile(uid)
        do {
            try await db.collection("users").document(user.id)
                .collection("requests").document(uid)
                .setData([
                    "fromUsername": me?.username ?? "?",
                    "fromAvatar": me?.avatarSymbol ?? "person.fill",
                    "fromLevel": me?.level ?? 1,
                    "fromScore": me?.score ?? 0,
                    "fromStreak": me?.streak ?? 0,
                    "createdAt": FieldValue.serverTimestamp()
                ])
        } catch {
            print("⚠️ Envoi de la demande d'ami échoué : \(error.localizedDescription)")
            throw SocialError.network
        }
    }

    func accept(_ request: FriendRequest) async {
        guard let uid = myUID else { return }
        let friendUID = request.id
        // Arête des deux côtés.
        try? await db.collection("users").document(uid)
            .collection("friends").document(friendUID)
            .setData(["since": FieldValue.serverTimestamp()])
        try? await db.collection("users").document(friendUID)
            .collection("friends").document(uid)
            .setData(["since": FieldValue.serverTimestamp()])
        // On retire la demande.
        try? await db.collection("users").document(uid)
            .collection("requests").document(friendUID).delete()
    }

    func decline(_ request: FriendRequest) async {
        guard let uid = myUID else { return }
        try? await db.collection("users").document(uid)
            .collection("requests").document(request.id).delete()
    }

    func remove(_ friend: UserProfile) async {
        guard let uid = myUID else { return }
        try? await db.collection("users").document(uid)
            .collection("friends").document(friend.id).delete()
        try? await db.collection("users").document(friend.id)
            .collection("friends").document(uid).delete()
    }

    func cheer(_ friend: UserProfile) async {
        guard let uid = myUID else { return }
        // Dépose un encouragement dans la boîte de l'ami.
        try? await db.collection("users").document(friend.id)
            .collection("cheers").addDocument(data: [
                "fromUID": uid,
                "createdAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: - Classement

    func leaderboard(kind: LeaderboardKind, me: UserProfile) async -> [LeaderboardEntry] {
        guard let uid = myUID else { return [] }
        let mine = await fetchProfile(uid) ?? me
        var everyone = await friends()
        everyone.append(mine)

        func value(_ p: UserProfile) -> Int {
            switch kind {
            case .streak: return p.streak
            case .completed: return p.score
            case .consistency: return min(100, p.score / 10)
            }
        }
        let sorted = everyone.sorted { value($0) > value($1) }
        return sorted.enumerated().map { idx, p in
            LeaderboardEntry(id: p.id, profile: p, rank: idx + 1, value: value(p), isMe: p.id == uid)
        }
    }

    // MARK: - Groupes

    func groups() async -> [SocialGroup] {
        guard let uid = myUID,
              let snap = try? await db.collection("groups")
                .whereField("members", arrayContains: uid)
                .getDocuments()
        else { return [] }
        return snap.documents.map { doc in
            let d = doc.data()
            let memberIDs = d["members"] as? [String] ?? []
            return SocialGroup(
                id: doc.documentID,
                name: d["name"] as? String ?? "Groupe",
                icon: d["icon"] as? String ?? "person.3.fill",
                memberCount: memberIDs.count,
                memberIDs: memberIDs,
                lastMessageAt: (d["lastMessageAt"] as? Timestamp)?.dateValue()
            )
        }
    }

    func members(of group: SocialGroup) async -> [UserProfile] {
        var result: [UserProfile] = []
        for uid in group.memberIDs {
            if let profile = await fetchProfile(uid) { result.append(profile) }
        }
        return result.sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
    }

    func addMembers(_ friends: [UserProfile], to group: SocialGroup) async throws {
        guard myUID != nil else { throw SocialError.notSignedIn }
        guard !friends.isEmpty else { return }
        do {
            try await db.collection("groups").document(group.id)
                .setData(["members": FieldValue.arrayUnion(friends.map(\.id))], merge: true)
        } catch {
            print("⚠️ Ajout de membres échoué : \(error.localizedDescription)")
            throw SocialError.network
        }
    }

    func createGroup(name: String, icon: String, friends: [UserProfile]) async throws {
        guard let uid = myUID else { throw SocialError.notSignedIn }
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        do {
            try await db.collection("groups").addDocument(data: [
                "name": clean,
                "icon": icon,
                "members": [uid] + friends.map(\.id),
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("⚠️ Création du groupe échouée : \(error.localizedDescription)")
            throw SocialError.network
        }
    }

    func messages(in group: SocialGroup) async -> [ChatMessage] {
        guard let uid = myUID,
              let snap = try? await db.collection("groups").document(group.id)
                .collection("messages")
                .order(by: "createdAt")
                .getDocuments()
        else { return [] }
        let blocked = await blockedUIDs()
        return snap.documents.compactMap { doc in
            let d = doc.data()
            let author = d["authorUID"] as? String ?? ""
            // Un utilisateur bloqué disparaît complètement de mon fil (règle 1.2).
            guard !blocked.contains(author) else { return nil }
            let ts = d["createdAt"] as? Timestamp
            return ChatMessage(
                id: doc.documentID,
                authorName: d["authorName"] as? String ?? "?",
                text: d["text"] as? String ?? "",
                date: ts?.dateValue() ?? .now,
                isMine: author == uid,
                authorUID: author
            )
        }
    }

    func send(_ text: String, to group: SocialGroup) async {
        guard let uid = myUID else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let myName = (await fetchProfile(uid))?.username ?? "Moi"
        try? await db.collection("groups").document(group.id)
            .collection("messages").addDocument(data: [
                "authorUID": uid,
                "authorName": myName,
                "text": clean,
                "createdAt": FieldValue.serverTimestamp()
            ])
        // Horodatage du dernier message → pastille « non lu » chez les autres membres.
        try? await db.collection("groups").document(group.id)
            .setData(["lastMessageAt": FieldValue.serverTimestamp()], merge: true)
    }

    // MARK: - Modération (règle App Store 1.2)

    func report(message: ChatMessage, in group: SocialGroup, reason: ReportReason) async {
        guard let uid = myUID else { return }
        // On copie le texte : le signalement doit rester examinable même si
        // l'auteur supprime son message ensuite.
        try? await db.collection("reports").addDocument(data: [
            "type": "message",
            "reporterUID": uid,
            "targetUID": message.authorUID,
            "targetName": message.authorName,
            "groupID": group.id,
            "messageID": message.id,
            "content": message.text,
            "reason": reason.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "open"
        ])
    }

    func report(user: UserProfile, reason: ReportReason) async {
        guard let uid = myUID else { return }
        try? await db.collection("reports").addDocument(data: [
            "type": "user",
            "reporterUID": uid,
            "targetUID": user.id,
            "targetName": user.username,
            "reason": reason.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "open"
        ])
    }

    func block(_ uid: String) async {
        guard let me = myUID, uid != me else { return }
        try? await db.collection("users").document(me)
            .collection("blocked").document(uid)
            .setData(["createdAt": FieldValue.serverTimestamp()])
    }

    func unblock(_ uid: String) async {
        guard let me = myUID else { return }
        try? await db.collection("users").document(me)
            .collection("blocked").document(uid).delete()
    }

    func blockedUIDs() async -> Set<String> {
        guard let me = myUID,
              let snap = try? await db.collection("users").document(me)
                .collection("blocked").getDocuments()
        else { return [] }
        return Set(snap.documents.map(\.documentID))
    }

    func blockedUsers() async -> [UserProfile] {
        var result: [UserProfile] = []
        for uid in await blockedUIDs() {
            if let p = await fetchProfile(uid) { result.append(p) }
        }
        return result.sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
    }
}
