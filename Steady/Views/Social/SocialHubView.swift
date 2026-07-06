import SwiftUI
import AuthenticationServices

/// Hub social : profil, amis, classements, groupes. Backend abstrait (Firebase).
struct SocialHubView: View {
    let myStreak: Int

    @State private var auth = AuthManager.shared
    @State private var store = SocialStore()
    @State private var tab: SocialTab = .friends
    @State private var showDeleteSheet = false
    @State private var draftPseudo = ""

    /// Pseudo encore jamais personnalisé → tes amis te verraient comme « Moi ».
    private var needsPseudo: Bool {
        let clean = store.username.trimmingCharacters(in: .whitespaces)
        return clean.isEmpty || clean == "Moi"
    }

    enum SocialTab: String, CaseIterable, Identifiable {
        case friends, leaderboard, groups
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .friends: return "Amis"
            case .leaderboard: return "Classement"
            case .groups: return "Groupes"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if auth.isSignedIn {
                    hub
                } else {
                    signInGate
                }
            }
            .background(AnimatedBackground())
            .navigationTitle("Communauté")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if auth.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            auth.signOut()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Se déconnecter")
                    }
                }
            }
        }
    }

    private var hub: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if needsPseudo { pseudoSetupCard }

                SocialProfileHeader(profile: store.myProfile, username: $store.username)

                Picker("", selection: $tab) {
                    ForEach(SocialTab.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .friends: FriendsSection(store: store)
                case .leaderboard: LeaderboardSection(store: store)
                case .groups: GroupsSection(store: store)
                }

                Button(role: .destructive) {
                    showDeleteSheet = true
                } label: {
                    Text("Supprimer mon compte")
                        .font(.footnote.weight(.semibold))
                }
                .padding(.top, Theme.Spacing.md)
            }
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .task(id: auth.uid) {
            store.myStreak = myStreak
            await store.refresh()
        }
        .sheet(isPresented: $showDeleteSheet) {
            DeleteAccountSheet(auth: auth, store: store)
        }
    }

    /// Carte affichée tant que le pseudo n'a pas été personnalisé :
    /// sans elle, tout le monde apparaît comme « Moi » chez ses amis.
    private var pseudoSetupCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Choisis ton pseudo", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentDeep)
            Text("C'est le nom que tes amis chercheront pour t'ajouter. Sans pseudo, tu apparais comme « Moi ».")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Ton pseudo", text: $draftPseudo)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.secondary.opacity(0.1)))
                Button {
                    store.username = draftPseudo.trimmingCharacters(in: .whitespaces)
                    HapticManager.success()
                } label: {
                    Text("Valider")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(Color.accentDeep))
                }
                .buttonStyle(.plain)
                .disabled(draftPseudo.trimmingCharacters(in: .whitespaces).count < 3)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Color.brandAccent.opacity(0.15))
        )
    }

    private var signInGate: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentGradient)
            Text("Rejoins la communauté")
                .font(.title2.weight(.bold))
            Text("Connecte-toi pour ajouter des amis, te comparer en douceur et avancer ensemble. Tes habitudes restent privées.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            SignInWithAppleButton(.signIn) { request in
                auth.prepareRequest(request)
            } onCompletion: { result in
                Task { await auth.handle(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(Capsule())
            .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - En-tête de profil

private struct SocialProfileHeader: View {
    let profile: UserProfile
    @Binding var username: String
    @State private var editing = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: profile.avatarSymbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.accentGradient))

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.username)
                    .font(.title3.weight(.bold))
                HStack(spacing: 10) {
                    Label("Niv. \(profile.level)", systemImage: "star.fill")
                    Label("\(profile.streak)", systemImage: "flame.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                editing = true
            } label: {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentDeep)
            }
            .accessibilityLabel("Modifier le pseudo")
        }
        .padding(Theme.Spacing.lg)
        .steadyCard()
        .alert("Ton pseudo", isPresented: $editing) {
            TextField("Pseudo", text: $username)
            Button("OK") {}
        }
    }
}

// MARK: - Suppression de compte

private struct DeleteAccountSheet: View {
    var auth: AuthManager
    var store: SocialStore
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Supprimer ton compte")
                    .font(.title2.weight(.bold))
                Text("Cette action efface définitivement ton profil, tes amis et tes données serveur. Tes habitudes restent sur ton appareil. Confirme ton identité avec Apple pour continuer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if working {
                    ProgressView().padding(.top)
                } else {
                    SignInWithAppleButton(.continue) { request in
                        auth.prepareRequest(request)
                    } onCompletion: { result in
                        working = true
                        Task {
                            await auth.deleteAccount(result) { await store.deleteMyData() }
                            working = false
                            dismiss()
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(Capsule())
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                Spacer()
                Spacer()
            }
            .padding()
            .background(AnimatedBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Amis

private struct FriendsSection: View {
    var store: SocialStore
    @State private var query = ""
    @State private var searching = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Recherche par pseudo
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Chercher un pseudo…", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { runSearch() }
                if !query.isEmpty {
                    Button {
                        query = ""
                        store.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
                Button {
                    runSearch()
                } label: {
                    if searching {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.right.circle.fill").font(.title2)
                    }
                }
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
            }
            .padding(Theme.Spacing.md)
            .steadyCard()

            // Message d'état (erreur réseau, aucun résultat…)
            if let message = store.searchMessage {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Résultats de la recherche
            if !store.searchResults.isEmpty {
                sectionTitle("Résultats")
                ForEach(store.searchResults) { user in
                    HStack(spacing: Theme.Spacing.md) {
                        avatar(user)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.username).font(.subheadline.weight(.semibold))
                            Label("Niv. \(user.level)", systemImage: "star.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if store.friends.contains(where: { $0.id == user.id }) {
                            Label("Déjà amis", systemImage: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else if store.sentInvites.contains(user.id) {
                            Label("Envoyé", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                        } else {
                            Button {
                                HapticManager.lightImpact()
                                Task { await store.invite(user) }
                            } label: {
                                Text("Inviter")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Capsule().fill(Color.accentDeep))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .steadyCard()
                }
            }

            // Demandes reçues
            if !store.requests.isEmpty {
                sectionTitle("Demandes")
                ForEach(store.requests) { req in
                    HStack {
                        avatar(req.from)
                        Text(req.from.username).font(.subheadline.weight(.semibold))
                        Spacer()
                        Button {
                            Task { await store.accept(req) }
                        } label: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        Button {
                            Task { await store.decline(req) }
                        } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }
                    .font(.title3)
                    .padding(Theme.Spacing.md)
                    .steadyCard()
                }
            }

            // Liste d'amis
            sectionTitle("Mes amis")
            if store.friends.isEmpty {
                Text("Aucun ami pour l'instant. Ajoute quelqu'un par son pseudo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
            } else {
                ForEach(store.friends) { friend in
                    HStack(spacing: Theme.Spacing.md) {
                        avatar(friend)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.username).font(.subheadline.weight(.semibold))
                            Label("\(friend.streak) j", systemImage: "flame.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            HapticManager.success()
                            Task { await store.cheer(friend) }
                        } label: {
                            Image(systemName: "hands.clap.fill")
                                .foregroundStyle(Color.accentDeep)
                        }
                        .accessibilityLabel("Encourager \(friend.username)")
                    }
                    .padding(Theme.Spacing.md)
                    .steadyCard()
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await store.remove(friend) }
                        } label: { Label("Retirer", systemImage: "person.badge.minus") }
                    }
                }
            }
        }
    }

    private func runSearch() {
        let term = query
        searching = true
        Task {
            await store.search(term)
            searching = false
        }
    }

    private func avatar(_ p: UserProfile) -> some View {
        Image(systemName: p.avatarSymbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.accentGradient))
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Classement

private struct LeaderboardSection: View {
    var store: SocialStore

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Picker("", selection: Binding(get: { store.kind }, set: { store.setKind($0) })) {
                ForEach(LeaderboardKind.allCases) { k in
                    Text(k.title).tag(k)
                }
            }
            .pickerStyle(.segmented)

            ForEach(store.leaderboard) { entry in
                HStack(spacing: Theme.Spacing.md) {
                    rankBadge(entry.rank)
                    Image(systemName: entry.profile.avatarSymbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.accentGradient))
                    Text(entry.isMe ? L("Moi") : entry.profile.username)
                        .font(.subheadline.weight(entry.isMe ? .bold : .semibold))
                    Spacer()
                    Text("\(entry.value)")
                        .font(.headline)
                        .foregroundStyle(Color.accentDeep)
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .fill(entry.isMe ? Color.brandAccent.opacity(0.15) : Color.steadyCard)
                )
            }
        }
    }

    private func rankBadge(_ rank: Int) -> some View {
        Group {
            if rank <= 3 {
                Image(systemName: "medal.fill")
                    .foregroundStyle(rank == 1 ? .yellow : rank == 2 ? .gray : .brown)
            } else {
                Text("\(rank)").foregroundStyle(.secondary)
            }
        }
        .font(.headline)
        .frame(width: 28)
    }
}

// MARK: - Groupes

private struct GroupsSection: View {
    var store: SocialStore

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            if store.groups.isEmpty {
                Text("Aucun groupe. Crée-en un pour avancer à plusieurs.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical)
            } else {
                ForEach(store.groups) { group in
                    NavigationLink {
                        GroupChatView(store: store, group: group)
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: group.icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentGradient))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                                Text("\(group.memberCount) membres")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(Theme.Spacing.md)
                        .steadyCard()
                    }
                }
            }
        }
    }
}

// MARK: - Chat de groupe

private struct GroupChatView: View {
    var store: SocialStore
    let group: SocialGroup

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(messages) { msg in
                        bubble(msg)
                    }
                }
                .padding()
            }

            HStack(spacing: Theme.Spacing.sm) {
                TextField("Message…", text: $draft, axis: .vertical)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.steadyCard))
                Button {
                    let text = draft
                    draft = ""
                    Task { messages = await store.send(text, to: group) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                        .foregroundStyle(Color.accentDeep)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .background(AnimatedBackground())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { messages = await store.messages(group) }
    }

    private func bubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isMine { Spacer(minLength: 40) }
            VStack(alignment: msg.isMine ? .trailing : .leading, spacing: 2) {
                if !msg.isMine {
                    Text(msg.authorName).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                Text(msg.text)
                    .font(.subheadline)
                    .foregroundStyle(msg.isMine ? .white : .primary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(msg.isMine ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadyCard))
                    )
            }
            if !msg.isMine { Spacer(minLength: 40) }
        }
    }
}
