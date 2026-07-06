import SwiftUI
import SwiftData

/// Écran des défis : tes défis en cours + catalogue à rejoindre.
struct ChallengeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Challenge.startDate, order: .reverse) private var challenges: [Challenge]
    @Query(sort: [SortDescriptor(\Habit.sortIndex), SortDescriptor(\Habit.creationDate)]) private var habits: [Habit]

    var store: HabitStore

    @State private var manager = ChallengeManager()
    @State private var showCelebration = false
    @State private var showPremium = false
    @State private var pendingTemplate: ChallengeTemplate?

    // Défis entre amis (Firebase).
    @State private var shared = SharedChallengeService()
    @State private var invites: [ChallengeInvite] = []
    @State private var participants: [String: [ChallengeParticipant]] = [:]
    @State private var inviteTarget: Challenge?
    @State private var showCreate = false

    private var myName: String {
        UserDefaults.standard.string(forKey: "steady_social_username") ?? "Moi"
    }

    private var isPremium: Bool { store.storeManager.isPremium }
    /// Gratuit : un seul défi actif à la fois.
    private var canJoinMore: Bool { isPremium || challenges.isEmpty }

    private var available: [ChallengeTemplate] {
        manager.templates.filter { template in
            !challenges.contains { $0.templateID == template.id }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if !invites.isEmpty {
                    section("Invitations d'amis") {
                        ForEach(invites) { invite in
                            inviteRow(invite)
                        }
                    }
                }

                if !challenges.isEmpty {
                    section("Tes défis") {
                        ForEach(challenges) { challenge in
                            ChallengeCard(
                                challenge: challenge,
                                linkedHabitName: linkedName(for: challenge),
                                isAuto: manager.isAuto(challenge),
                                daysRemaining: manager.daysRemaining(challenge),
                                expired: manager.isExpired(challenge),
                                canAdvance: manager.canAdvanceToday(challenge),
                                participants: challenge.sharedID.flatMap { participants[$0] } ?? [],
                                onAdvance: { amount in
                                    if manager.advance(challenge, by: amount) { showCelebration = true }
                                    pushProgress(challenge)
                                },
                                onAbandon: {
                                    if let sid = challenge.sharedID {
                                        Task { await shared.leave(sharedID: sid) }
                                    }
                                    manager.abandon(challenge)
                                },
                                onInvite: shared.isSignedIn ? { inviteTarget = challenge } : nil
                            )
                        }
                    }
                }

                createButton

                if !available.isEmpty {
                    section("Découvrir") {
                        ForEach(available) { template in
                            availableRow(template)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(AnimatedBackground())
        .overlay {
            if showCelebration { CelebrationView(isPresented: $showCelebration) }
        }
        .navigationTitle("Défis")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremium) {
            PremiumView(storeManager: store.storeManager)
        }
        .sheet(item: $pendingTemplate) { template in
            ChallengeHabitPicker(habits: habits) { habit in
                manager.join(template, habit: habit)
                pendingTemplate = nil
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateChallengeView(habits: habits) { title, icon, target, unit, isDaily, windowDays, habit in
                manager.createCustom(title: title, icon: icon, target: target, unit: unit,
                                     isDaily: isDaily, windowDays: windowDays, habit: habit)
            }
        }
        .sheet(item: $inviteTarget) { challenge in
            InviteFriendsSheet(challenge: challenge, shared: shared) { sharedID in
                challenge.sharedID = sharedID
                try? modelContext.save()
                Task { await refreshShared() }
            }
        }
        .onAppear {
            manager.configure(modelContext)
            manager.refresh(challenges, habits: habits)
        }
        .task {
            invites = await shared.invites()
            await refreshShared()
        }
    }

    // MARK: - Défis entre amis

    /// Bouton « Créer mon propre défi ».
    private var createButton: some View {
        Button {
            guard canJoinMore else { showPremium = true; return }
            showCreate = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: canJoinMore ? "plus.circle.fill" : "lock.fill")
                Text("Créer mon propre défi")
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.accentDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .strokeBorder(Color.accentDeep.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }

    /// Carte d'une invitation reçue : accepter ou refuser.
    private func inviteRow(_ invite: ChallengeInvite) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: invite.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.accentGradient))

            VStack(alignment: .leading, spacing: 2) {
                Text(invite.title).font(.subheadline.weight(.semibold))
                Text(L("De \(invite.fromUsername) · \(invite.target) \(invite.unit)"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)

            Button {
                accept(invite)
            } label: {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            Button {
                Task {
                    await shared.decline(invite)
                    invites = await shared.invites()
                }
            } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }

    /// Accepte l'invitation : rejoint le défi sur Firebase + crée la copie locale.
    private func accept(_ invite: ChallengeInvite) {
        guard canJoinMore else { showPremium = true; return }
        Task {
            do {
                try await shared.accept(invite, myName: myName)
                manager.joinShared(invite)
                invites = await shared.invites()
                await refreshShared()
            } catch {
                // L'invitation reste affichée : l'utilisateur peut réessayer.
            }
        }
    }

    /// Pousse ma progression d'un défi partagé et recharge celle des amis.
    private func pushProgress(_ challenge: Challenge) {
        guard let sid = challenge.sharedID else { return }
        let progress = challenge.progress
        Task {
            await shared.updateProgress(sharedID: sid, progress: progress)
            participants[sid] = await shared.participants(sharedID: sid)
        }
    }

    /// Synchronise tous mes défis partagés (ma progression ↑, celle des amis ↓).
    private func refreshShared() async {
        for challenge in challenges {
            guard let sid = challenge.sharedID else { continue }
            await shared.updateProgress(sharedID: sid, progress: challenge.progress)
            participants[sid] = await shared.participants(sharedID: sid)
        }
    }

    private func linkedName(for challenge: Challenge) -> String? {
        guard let id = challenge.habitID else { return nil }
        return habits.first { $0.id == id }?.name
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }

    private func availableRow(_ template: ChallengeTemplate) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: template.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(template.color.gradient))

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(.subheadline.weight(.semibold))
                Text(template.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)

            Button {
                guard canJoinMore else { showPremium = true; return }
                // Défi quotidien + habitudes existantes → on le relie à une habitude.
                if template.isDaily && !habits.isEmpty {
                    pendingTemplate = template
                } else {
                    manager.join(template, habit: nil)
                }
            } label: {
                HStack(spacing: 4) {
                    if !canJoinMore { Image(systemName: "lock.fill") }
                    Text(canJoinMore ? "Rejoindre" : "Premium")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(template.color))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
    }
}

// MARK: - Sélecteur d'habitude à lier

private struct ChallengeHabitPicker: View {
    let habits: [Habit]
    var onPick: (Habit?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    Text("Relie ce défi à une habitude : il progressera automatiquement quand tu la valides.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Theme.Spacing.sm)

                    ForEach(habits) { habit in
                        Button {
                            onPick(habit)
                            dismiss()
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: habit.icon)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(Circle().fill(Color.accentGradient))
                                Text(habit.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .steadyCard(cornerRadius: Theme.Radius.md)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onPick(nil)
                        dismiss()
                    } label: {
                        Text("Sans habitude (suivi manuel)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Theme.Spacing.sm)
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Relier une habitude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}
