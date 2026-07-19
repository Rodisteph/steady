import SwiftUI

/// Profil social d'un utilisateur (le mien ou un ami).
struct UserProfile: Identifiable, Hashable {
    let id: String
    var username: String
    var avatarSymbol: String
    var level: Int
    var score: Int
    var streak: Int
}

/// Encouragement reçu d'un ami (« 👏 »).
struct Cheer: Identifiable, Hashable {
    let id: String
    let fromUID: String
    /// Pseudo dénormalisé à l'écriture : évite une lecture de profil par
    /// encouragement, et le message reste lisible même si l'ami se supprime.
    let fromUsername: String
    let date: Date
}

/// Demande d'ami reçue.
struct FriendRequest: Identifiable, Hashable {
    let id: String
    let from: UserProfile
}

/// Entrée de classement.
struct LeaderboardEntry: Identifiable, Hashable {
    let id: String
    let profile: UserProfile
    let rank: Int
    let value: Int
    var isMe: Bool
}

enum LeaderboardKind: String, CaseIterable, Identifiable {
    case streak, completed, consistency
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .streak: return "Série"
        case .completed: return "Validations"
        case .consistency: return "Régularité"
        }
    }
}

/// Groupe privé.
struct SocialGroup: Identifiable, Hashable {
    let id: String
    var name: String
    var icon: String
    var memberCount: Int
    /// uid des membres (pour afficher leurs profils).
    var memberIDs: [String] = []
    /// Date du dernier message (pour la pastille « non lu »).
    var lastMessageAt: Date? = nil
    /// Auteur du dernier message : si c'est moi, pas de pastille « non lu ».
    var lastMessageAuthorUID: String? = nil
}

/// Message de chat de groupe.
struct ChatMessage: Identifiable, Hashable {
    let id: String
    let authorName: String
    let text: String
    let date: Date
    let isMine: Bool
    /// uid de l'auteur : nécessaire pour le signalement et le blocage (règle 1.2).
    var authorUID: String = ""
}
