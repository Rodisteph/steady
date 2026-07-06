import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Invitation à un défi, reçue d'un ami.
struct ChallengeInvite: Identifiable, Hashable {
    let id: String          // = identifiant du défi partagé
    let title: String
    let icon: String
    let target: Int
    let unit: String
    let isDaily: Bool
    let fromUsername: String
    let deadline: Date
}

/// Un participant à un défi partagé, avec sa progression.
struct ChallengeParticipant: Identifiable, Hashable {
    let id: String          // uid Firebase
    let name: String
    let progress: Int
    let isMe: Bool
}

/// Défis partagés entre amis via Firestore.
/// Modèle de données :
///   sharedChallenges/{id}              → { title, icon, target, unit, isDaily, ownerUID,
///                                          deadline, members:[uid], names:{uid:pseudo}, progress:{uid:Int} }
///   users/{uid}/challengeInvites/{id}  → invitation en attente (copie des infos du défi)
@MainActor
final class SharedChallengeService {
    private let db = Firestore.firestore()
    private var myUID: String? { Auth.auth().currentUser?.uid }
    var isSignedIn: Bool { myUID != nil }

    /// Crée (ou met à jour) le défi partagé puis dépose une invitation chez chaque ami choisi.
    /// Renvoie l'identifiant du défi partagé, à stocker dans `Challenge.sharedID`.
    func share(_ challenge: Challenge, with friends: [UserProfile], myName: String) async throws -> String {
        guard let uid = myUID else { throw SocialError.notSignedIn }
        let sharedID = challenge.sharedID ?? challenge.id.uuidString
        do {
            try await db.collection("sharedChallenges").document(sharedID).setData([
                "title": challenge.title,
                "icon": challenge.icon,
                "target": challenge.target,
                "unit": challenge.unit,
                "isDaily": challenge.isDaily,
                "ownerUID": uid,
                "deadline": Timestamp(date: challenge.deadline),
                "members": FieldValue.arrayUnion([uid]),
                "names": [uid: myName],
                "progress": [uid: challenge.progress],
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)

            for friend in friends {
                try await db.collection("users").document(friend.id)
                    .collection("challengeInvites").document(sharedID)
                    .setData([
                        "title": challenge.title,
                        "icon": challenge.icon,
                        "target": challenge.target,
                        "unit": challenge.unit,
                        "isDaily": challenge.isDaily,
                        "fromUsername": myName,
                        "deadline": Timestamp(date: challenge.deadline),
                        "createdAt": FieldValue.serverTimestamp()
                    ])
            }
        } catch {
            print("⚠️ Partage du défi échoué : \(error.localizedDescription)")
            throw SocialError.network
        }
        return sharedID
    }

    /// Invitations à des défis que j'ai reçues.
    func invites() async -> [ChallengeInvite] {
        guard let uid = myUID,
              let snap = try? await db.collection("users").document(uid)
                .collection("challengeInvites").getDocuments()
        else { return [] }
        return snap.documents.map { doc in
            let d = doc.data()
            return ChallengeInvite(
                id: doc.documentID,
                title: d["title"] as? String ?? "Défi",
                icon: d["icon"] as? String ?? "trophy.fill",
                target: d["target"] as? Int ?? 1,
                unit: d["unit"] as? String ?? "",
                isDaily: d["isDaily"] as? Bool ?? false,
                fromUsername: d["fromUsername"] as? String ?? "?",
                deadline: (d["deadline"] as? Timestamp)?.dateValue() ?? .now
            )
        }
    }

    /// Accepte une invitation : je deviens membre du défi partagé, l'invitation disparaît.
    func accept(_ invite: ChallengeInvite, myName: String) async throws {
        guard let uid = myUID else { throw SocialError.notSignedIn }
        do {
            try await db.collection("sharedChallenges").document(invite.id).setData([
                "members": FieldValue.arrayUnion([uid]),
                "names": [uid: myName],
                "progress": [uid: 0]
            ], merge: true)
            try await db.collection("users").document(uid)
                .collection("challengeInvites").document(invite.id).delete()
        } catch {
            print("⚠️ Acceptation du défi échouée : \(error.localizedDescription)")
            throw SocialError.network
        }
    }

    /// Refuse une invitation (la supprime simplement).
    func decline(_ invite: ChallengeInvite) async {
        guard let uid = myUID else { return }
        try? await db.collection("users").document(uid)
            .collection("challengeInvites").document(invite.id).delete()
    }

    /// Pousse ma progression vers le défi partagé.
    func updateProgress(sharedID: String, progress: Int) async {
        guard let uid = myUID else { return }
        try? await db.collection("sharedChallenges").document(sharedID)
            .updateData(["progress.\(uid)": progress])
    }

    /// Tous les participants du défi, triés par progression (moi inclus).
    func participants(sharedID: String) async -> [ChallengeParticipant] {
        guard let snap = try? await db.collection("sharedChallenges").document(sharedID).getDocument(),
              let d = snap.data() else { return [] }
        let members = d["members"] as? [String] ?? []
        let names = d["names"] as? [String: String] ?? [:]
        let progress = d["progress"] as? [String: Int] ?? [:]
        return members
            .map { uid in
                ChallengeParticipant(id: uid, name: names[uid] ?? "?",
                                     progress: progress[uid] ?? 0, isMe: uid == myUID)
            }
            .sorted { $0.progress > $1.progress }
    }

    /// Quitte un défi partagé (quand j'abandonne le défi en local).
    func leave(sharedID: String) async {
        guard let uid = myUID else { return }
        try? await db.collection("sharedChallenges").document(sharedID)
            .updateData([
                "members": FieldValue.arrayRemove([uid]),
                "names.\(uid)": FieldValue.delete(),
                "progress.\(uid)": FieldValue.delete()
            ])
    }
}
