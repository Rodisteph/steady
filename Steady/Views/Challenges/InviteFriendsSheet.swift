import SwiftUI

/// Choisir des amis à inviter sur un défi. Envoie les invitations via Firebase.
struct InviteFriendsSheet: View {
    let challenge: Challenge
    let shared: SharedChallengeService
    /// Appelé quand le partage a réussi, avec l'identifiant du défi partagé.
    var onShared: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [UserProfile] = []
    @State private var selected: Set<String> = []
    @State private var loading = true
    @State private var sending = false
    @State private var errorMessage: String?

    private var myName: String {
        UserDefaults.standard.string(forKey: "steady_social_username") ?? "Moi"
    }

    /// Message d'invitation pour les amis qui n'ont pas encore l'app.
    /// Le lien rend le message cliquable dans WhatsApp (aperçu + accès à l'app).
    private var inviteMessage: String {
        L("Je relève le défi « \(challenge.title) » sur Steady 💪 Rejoins-moi, on le fait ensemble !")
        + "\n" + AppLinks.appStoreURL.absoluteString
    }

    /// Lien officiel WhatsApp : ouvre l'app avec le message pré-rempli.
    private var whatsAppURL: URL? {
        guard let encoded = inviteMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://wa.me/?text=\(encoded)")
    }

    /// Inviter hors app (WhatsApp ou autre) — pour les amis pas encore sur Steady.
    private var externalInviteSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Ton ami n'est pas encore sur Steady ?")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Theme.Spacing.sm) {
                if let whatsAppURL {
                    Link(destination: whatsAppURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "message.fill")
                            Text("WhatsApp")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color(red: 0.14, green: 0.75, blue: 0.38)))
                    }
                }
                ShareLink(item: inviteMessage) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Autre app")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().strokeBorder(Color.accentDeep.opacity(0.5), lineWidth: 1.5))
                }
            }
        }
        .padding(.top, Theme.Spacing.md)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if loading {
                        ProgressView().padding(.top, Theme.Spacing.xl)
                    } else if friends.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Aucun ami pour l'instant")
                                .font(.headline)
                            Text("Ajoute d'abord des amis dans l'onglet Communauté (recherche par pseudo), puis reviens ici les défier.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Theme.Spacing.xl)
                    } else {
                        Text("Ils recevront une invitation dans leur écran Défis et devront l'accepter pour participer.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, Theme.Spacing.sm)

                        ForEach(friends) { friend in
                            Button {
                                if selected.contains(friend.id) {
                                    selected.remove(friend.id)
                                } else {
                                    selected.insert(friend.id)
                                }
                                HapticManager.lightImpact()
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: friend.avatarSymbol)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Color.accentGradient))
                                    Text(friend.username)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: selected.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selected.contains(friend.id) ? Color.accentDeep : .secondary)
                                }
                                .padding(Theme.Spacing.md)
                                .steadyCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !loading {
                        externalInviteSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Défier des amis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !friends.isEmpty {
                    Button {
                        sendInvites()
                    } label: {
                        if sending {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.accentGradient))
                        } else {
                            Text(selected.isEmpty ? L("Choisis au moins un ami") : L("Envoyer (\(selected.count))"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(selected.isEmpty ? AnyShapeStyle(Color.secondary.opacity(0.3)) : AnyShapeStyle(Color.accentGradient)))
                        }
                    }
                    .disabled(selected.isEmpty || sending)
                    .padding(.horizontal)
                    .padding(.bottom, Theme.Spacing.sm)
                }
            }
            .task {
                friends = await FirebaseSocialService().friends()
                loading = false
            }
        }
    }

    private func sendInvites() {
        let chosen = friends.filter { selected.contains($0.id) }
        sending = true
        errorMessage = nil
        Task {
            do {
                let id = try await shared.share(challenge, with: chosen, myName: myName)
                HapticManager.success()
                onShared(id)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            sending = false
        }
    }
}
