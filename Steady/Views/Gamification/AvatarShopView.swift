import SwiftUI

/// Article de la boutique d'avatars.
struct AvatarItem: Identifiable {
    let symbol: String
    let cost: Int
    /// Avatar exclusif : achetable uniquement par les membres Premium.
    var premiumOnly: Bool = false
    var id: String { symbol }
}

enum AvatarShop {
    /// Avatars achetables avec les pièces gagnées en validant des habitudes.
    static let all: [AvatarItem] = [
        AvatarItem(symbol: "flame.fill", cost: 50),
        AvatarItem(symbol: "bolt.fill", cost: 50),
        AvatarItem(symbol: "heart.fill", cost: 75),
        AvatarItem(symbol: "star.fill", cost: 75),
        AvatarItem(symbol: "hare.fill", cost: 100),
        AvatarItem(symbol: "tortoise.fill", cost: 100),
        AvatarItem(symbol: "leaf.fill", cost: 100),
        AvatarItem(symbol: "moon.stars.fill", cost: 120),
        AvatarItem(symbol: "bird.fill", cost: 120),
        AvatarItem(symbol: "sun.max.fill", cost: 120),
        AvatarItem(symbol: "pawprint.fill", cost: 150),
        AvatarItem(symbol: "brain.head.profile", cost: 150),
        AvatarItem(symbol: "figure.run", cost: 175),
        AvatarItem(symbol: "crown.fill", cost: 200),
        AvatarItem(symbol: "diamond.fill", cost: 250),
        AvatarItem(symbol: "trophy.fill", cost: 300),
        // --- Exclusifs Premium ---
        AvatarItem(symbol: "sparkles", cost: 200, premiumOnly: true),
        AvatarItem(symbol: "wand.and.stars", cost: 250, premiumOnly: true),
        AvatarItem(symbol: "flame.circle.fill", cost: 300, premiumOnly: true),
        AvatarItem(symbol: "medal.fill", cost: 350, premiumOnly: true),
        AvatarItem(symbol: "rosette", cost: 400, premiumOnly: true),
        AvatarItem(symbol: "laurel.leading", cost: 500, premiumOnly: true)
    ]
}

/// Boutique : dépense tes pièces pour débloquer et équiper des avatars.
struct AvatarShopView: View {
    var isPremium: Bool = false
    private var game = GamificationManager.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.md)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    balanceCard
                    autoAvatarCard
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                        ForEach(AvatarShop.all) { item in
                            avatarCell(item)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    /// Objectif de dépense : l'avatar accessible le plus proche que l'on ne
    /// possède pas encore. Donne un but concret à la collecte de pièces.
    private var spendingGoal: (item: AvatarItem, missing: Int)? {
        let candidates = AvatarShop.all
            .filter { !game.isUnlocked($0.symbol) && (!$0.premiumOnly || isPremium) }
            .sorted { $0.cost < $1.cost }
        // Le premier qu'on ne peut pas encore s'offrir (sinon on peut déjà acheter).
        if let next = candidates.first(where: { $0.cost > game.coins }) {
            return (next, next.cost - game.coins)
        }
        return nil
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "star.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.steadyFlame)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(game.coins)")
                        .font(.title2.weight(.bold))
                        .contentTransition(.numericText())
                    Text("pièces disponibles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let goal = spendingGoal {
                let target = Double(goal.item.cost)
                ProgressView(value: min(Double(game.coins), target), total: target)
                    .tint(Color.accentDeep)
                Label(L("Plus que \(goal.missing) pièces pour un nouvel avatar"),
                      systemImage: goal.item.symbol)
                    .font(.caption2).foregroundStyle(.secondary)
            } else if game.coins > 0 {
                Label("Tu peux débloquer un nouvel avatar !", systemImage: "sparkles")
                    .font(.caption2.weight(.semibold)).foregroundStyle(Color.accentDeep)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }

    /// Permet de revenir à l'avatar automatique (lié au niveau).
    private var autoAvatarCard: some View {
        let isAuto = game.selectedAvatar == nil
        return Button {
            game.select(nil)
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                avatarCircle(game.levelAvatar, selected: isAuto)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatique").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("Évolue avec ton niveau").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isAuto {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentDeep)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .steadyCard()
        }
        .buttonStyle(.plain)
    }

    private func avatarCell(_ item: AvatarItem) -> some View {
        let unlocked = game.isUnlocked(item.symbol)
        let selected = game.selectedAvatar == item.symbol
        let affordable = game.coins >= item.cost
        let premiumLocked = item.premiumOnly && !isPremium && !unlocked

        return Button {
            if premiumLocked {
                HapticManager.lightImpact()   // exclusif Premium : pas achetable
                return
            }
            if unlocked {
                game.select(item.symbol)
                HapticManager.lightImpact()
            } else if game.unlock(item.symbol, cost: item.cost) {
                HapticManager.success()
            }
        } label: {
            VStack(spacing: 8) {
                avatarCircle(item.symbol, selected: selected, locked: !unlocked)
                if unlocked {
                    Text(selected ? "Équipé" : "Choisir")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selected ? Color.accentDeep : .secondary)
                } else if premiumLocked {
                    Label("Premium", systemImage: "crown.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentDeep)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "star.circle.fill").font(.caption2)
                        Text("\(item.cost)").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(affordable ? Color.accentDeep : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .steadyCard(cornerRadius: Theme.Radius.md)
            .overlay(alignment: .topTrailing) {
                if item.premiumOnly {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.steadyFlame)
                        .padding(6)
                }
            }
            .opacity(premiumLocked ? 0.5 : (unlocked || affordable ? 1 : 0.55))
        }
        .buttonStyle(.plain)
    }

    private func avatarCircle(_ symbol: String, selected: Bool, locked: Bool = false) -> some View {
        ZStack {
            Circle()
                .fill(selected ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadySurface))
                .frame(width: 56, height: 56)
            Image(systemName: locked ? "lock.fill" : symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(selected ? .white : (locked ? Color.secondary : Color.accentDeep))
        }
        .overlay(Circle().strokeBorder(Color.accentDeep.opacity(selected ? 0.9 : 0), lineWidth: 2))
    }
}

#Preview {
    AvatarShopView()
}
