import SwiftUI

/// Carte d'un défi rejoint (composant réutilisable).
struct ChallengeCard: View {
    let challenge: Challenge
    var linkedHabitName: String?
    var isAuto: Bool
    /// Piloté par Apple Santé (message de pied de carte adapté).
    var healthLinked: Bool = false
    var daysRemaining: Int
    var expired: Bool
    var canAdvance: Bool
    /// Participants du défi partagé (vide = défi solo).
    var participants: [ChallengeParticipant] = []
    var onAdvance: (Int) -> Void
    var onAbandon: () -> Void
    /// Ouvre la feuille « Défier des amis » (nil = pas connecté → partage texte classique).
    var onInvite: (() -> Void)?
    /// Annule un check-in fait par erreur (quotidien : la validation du jour ;
    /// cumulatif : -1). nil = pas d'annulation possible (défi auto).
    var onUndo: ((Int) -> Void)?

    private var template: ChallengeTemplate? { ChallengeCatalog.template(for: challenge.templateID) }
    private var tint: Color { template?.color ?? .accentDeep }
    private var displayName: String { template?.name ?? challenge.title }
    private var displayUnit: String { template?.unit ?? challenge.unit }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: challenge.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(tint.gradient))

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if challenge.isCompleted {
                    Image(systemName: "trophy.fill").font(.title3).foregroundStyle(tint)
                } else {
                    // Défi entre amis : invite quelqu'un à le faire avec toi.
                    if let onInvite {
                        Button {
                            onInvite()
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(tint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Défier un ami")
                    } else {
                        ShareLink(item: L("Je relève le défi « \(displayName) » sur Steady 💪 Rejoins-moi, on le fait ensemble !")) {
                            Image(systemName: "person.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(tint)
                        }
                        .accessibilityLabel("Défier un ami")
                    }
                    deadlineChip
                }
            }

            ChallengeProgress(progress: challenge.progress, target: challenge.target, tint: tint)

            // Progression des amis sur un défi partagé.
            if participants.count > 1 {
                VStack(spacing: 6) {
                    ForEach(participants) { p in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: p.isMe ? "person.fill" : "person")
                                .font(.caption2)
                                .foregroundStyle(p.isMe ? tint : .secondary)
                            Text(p.isMe ? L("Moi") : p.name)
                                .font(.caption.weight(p.isMe ? .bold : .medium))
                            Spacer()
                            Text("\(min(p.progress, challenge.target))/\(challenge.target)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(p.progress >= challenge.target ? tint : .secondary)
                            if p.progress >= challenge.target {
                                Image(systemName: "trophy.fill").font(.caption2).foregroundStyle(tint)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(tint.opacity(0.08)))
            }

            footer
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .contextMenu {
            Button(role: .destructive) { onAbandon() } label: {
                Label(challenge.isCompleted || expired ? "Retirer" : "Abandonner le défi", systemImage: "xmark.circle")
            }
        }
    }

    private var subtitle: String {
        if let name = linkedHabitName {
            return "\(challenge.target) \(displayUnit) · " + L("lié à « \(name) »")
        }
        return "\(challenge.target) \(displayUnit)"
    }

    @ViewBuilder
    private var deadlineChip: some View {
        if expired {
            Label("Expiré", systemImage: "clock.badge.xmark")
                .font(.caption2.weight(.bold)).foregroundStyle(.orange)
        } else {
            Text("J-\(daysRemaining)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(daysRemaining <= 3 ? .orange : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
    }

    @ViewBuilder
    private var footer: some View {
        if challenge.isCompleted {
            HStack(spacing: Theme.Spacing.md) {
                Label("Défi réussi !", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                Spacer()
                rewardChip
            }
        } else if expired {
            Label("Temps écoulé. Relance-le quand tu veux.", systemImage: "arrow.clockwise")
                .font(.caption).foregroundStyle(.secondary)
        } else if healthLinked {
            Label("Progresse tout seul via Apple Santé", systemImage: "heart.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(tint)
        } else if isAuto {
            Label(linkedHabitName.map { L("Avance tout seul avec « \($0) »") } ?? L("Avance avec ton habitude"),
                  systemImage: "wand.and.stars")
                .font(.caption.weight(.medium))
                .foregroundStyle(tint)
        } else if challenge.isDaily {
            VStack(spacing: 6) {
                advanceButton(title: canAdvance ? "Valider aujourd'hui" : "Déjà validé aujourd'hui", amount: 1, enabled: canAdvance)
                // Tap par erreur ? On peut annuler la validation du jour.
                if !canAdvance, let onUndo {
                    Button {
                        onUndo(1)
                    } label: {
                        Label("Annuler la validation d'aujourd'hui", systemImage: "arrow.uturn.backward")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            HStack(spacing: Theme.Spacing.sm) {
                if let onUndo, challenge.progress > 0 {
                    Button {
                        onUndo(1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: 44)
                            .padding(.vertical, 10)
                            .background(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retirer 1 (erreur de saisie)")
                }
                advanceButton(title: "+1", amount: 1, enabled: true)
                advanceButton(title: "+10", amount: 10, enabled: true)
            }
        }
    }

    private var rewardChip: some View {
        HStack(spacing: 8) {
            Label("\(challenge.rewardCoins)", systemImage: "star.circle.fill").foregroundStyle(Color.steadyFlame)
            Label("\(challenge.rewardXP) XP", systemImage: "bolt.fill").foregroundStyle(tint)
        }
        .font(.caption2.weight(.bold))
    }

    private func advanceButton(title: LocalizedStringKey, amount: Int, enabled: Bool) -> some View {
        Button { onAdvance(amount) } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(enabled ? AnyShapeStyle(tint) : AnyShapeStyle(Color.secondary.opacity(0.2)))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .disabled(!enabled)
    }
}
