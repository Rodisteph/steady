import SwiftUI
import Observation

/// Système de jeu local : XP, pièces, niveaux. Gagnés en validant des habitudes.
@MainActor
@Observable
final class GamificationManager {
    static let shared = GamificationManager()

    private let xpPerLevel = 100

    private(set) var xp: Int {
        didSet { UserDefaults.standard.set(xp, forKey: "steady_xp") }
    }
    private(set) var coins: Int {
        didSet { UserDefaults.standard.set(coins, forKey: "steady_coins") }
    }

    /// Avatars achetés avec des pièces.
    private(set) var unlockedAvatars: Set<String> {
        didSet { UserDefaults.standard.set(Array(unlockedAvatars), forKey: "steady_unlocked_avatars") }
    }
    /// Avatar choisi par l'utilisateur (prioritaire sur l'avatar de niveau). `nil` = automatique.
    private(set) var selectedAvatar: String? {
        didSet { UserDefaults.standard.set(selectedAvatar, forKey: "steady_selected_avatar") }
    }

    /// Registre anti-triche : clés des récompenses DÉJÀ versées (habitude-jour, défi…).
    /// Empêche de farmer l'XP en cochant/décochant ou en rejoignant un défi.
    private var rewardedKeys: Set<String> {
        didSet { UserDefaults.standard.set(Array(rewardedKeys), forKey: "steady_rewarded_keys") }
    }

    /// Dernier gain (XP + pièces) : sert au petit « +10 XP · +5 🪙 » flottant.
    /// `id` change à chaque gain pour redéclencher l'animation même si les
    /// montants sont identiques.
    struct RewardGain: Equatable { let id = UUID(); let xp: Int; let coins: Int; let leveledUp: Bool }
    private(set) var lastReward: RewardGain?

    private init() {
        xp = UserDefaults.standard.integer(forKey: "steady_xp")
        coins = UserDefaults.standard.integer(forKey: "steady_coins")
        unlockedAvatars = Set(UserDefaults.standard.stringArray(forKey: "steady_unlocked_avatars") ?? [])
        selectedAvatar = UserDefaults.standard.string(forKey: "steady_selected_avatar")
        rewardedKeys = Set(UserDefaults.standard.stringArray(forKey: "steady_rewarded_keys") ?? [])
    }

    // MARK: - Niveaux

    var level: Int { xp / xpPerLevel + 1 }
    var xpInLevel: Int { xp % xpPerLevel }
    var xpForNextLevel: Int { xpPerLevel }
    var progress: Double { Double(xpInLevel) / Double(xpPerLevel) }

    /// Avatar affiché : celui choisi dans la boutique, sinon celui qui évolue avec le niveau.
    var avatarSymbol: String {
        if let selectedAvatar, unlockedAvatars.contains(selectedAvatar) { return selectedAvatar }
        return levelAvatar
    }

    /// Avatar par défaut, qui évolue avec le niveau (toujours disponible).
    var levelAvatar: String {
        switch level {
        case 1...2: return "leaf.fill"
        case 3...5: return "tree.fill"
        case 6...9: return "sparkles"
        default: return "crown.fill"
        }
    }

    // MARK: - Boutique d'avatars

    func isUnlocked(_ symbol: String) -> Bool { unlockedAvatars.contains(symbol) }

    /// Tente d'acheter un avatar. Renvoie `true` si l'achat a réussi.
    @discardableResult
    func unlock(_ symbol: String, cost: Int) -> Bool {
        guard !unlockedAvatars.contains(symbol), coins >= cost else { return false }
        coins -= cost
        unlockedAvatars.insert(symbol)
        selectedAvatar = symbol   // on l'équipe directement
        return true
    }

    /// Sélectionne un avatar déjà débloqué (ou repasse en automatique avec `nil`).
    func select(_ symbol: String?) {
        if let symbol { guard unlockedAvatars.contains(symbol) else { return } }
        selectedAvatar = symbol
    }

    // MARK: - Gains

    /// Appelé quand une habitude vient d'être complétée. Renvoie `true` si on monte de niveau.
    /// La clé (habitude-jour) garantit UNE récompense par habitude et par jour :
    /// décocher puis recocher ne redonne pas d'XP.
    /// `multiplier` = 2 pour les membres Premium (récompenses doublées).
    @discardableResult
    func awardCompletion(streak: Int, key: String, multiplier: Int = 1) -> Bool {
        guard !rewardedKeys.contains(key) else { return false }
        rewardedKeys.insert(key)
        let before = level
        let m = max(1, multiplier)
        let xpGain = (10 + min(max(streak, 0), 10)) * m   // bonus jusqu'à +10 selon la série
        let coinGain = 5 * m
        xp += xpGain
        coins += coinGain
        let leveled = level > before
        lastReward = RewardGain(xp: xpGain, coins: coinGain, leveledUp: leveled)
        return leveled
    }

    /// Récompense ponctuelle protégée par une clé (ex. défi réussi) : versée une seule fois.
    /// Empêche de re-gagner en abandonnant puis en rejoignant le même défi.
    func grantOnce(key: String, xp: Int, coins: Int) {
        guard !rewardedKeys.contains(key) else { return }
        rewardedKeys.insert(key)
        self.xp += max(0, xp)
        self.coins += max(0, coins)
    }

    /// Récompense ponctuelle non protégée (usage interne rare).
    func grant(xp: Int, coins: Int) {
        self.xp += max(0, xp)
        self.coins += max(0, coins)
    }

    /// Dépense des pièces si le solde le permet. Renvoie `false` sinon.
    @discardableResult
    func spend(coins amount: Int) -> Bool {
        guard amount > 0, coins >= amount else { return false }
        coins -= amount
        return true
    }
}
