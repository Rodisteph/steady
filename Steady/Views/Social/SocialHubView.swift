import SwiftUI
import AuthenticationServices

/// Hub social : profil, amis, classements, groupes. Backend abstrait (Firebase).
struct SocialHubView: View {
    let myStreak: Int

    @State private var auth = AuthManager.shared
    @State private var store = SocialStore()
    @State private var tab: SocialTab = .friends
    @State private var showDeleteSheet = false
    @State private var showBlocked = false
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
            case .groups: return "Messages"
            }
        }
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .leaderboard: return "trophy.fill"
            case .groups: return "bubble.left.and.bubble.right.fill"
            }
        }
    }

    /// Au moins un groupe a-t-il des messages non lus ? (pastille sur l'onglet Messages)
    private var hasUnreadGroups: Bool {
        store.groups.contains { store.hasUnread($0) }
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

                socialTabBar

                switch tab {
                case .friends: FriendsSection(store: store)
                case .leaderboard: LeaderboardSection(store: store)
                case .groups: GroupsSection(store: store)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Button {
                        showBlocked = true
                    } label: {
                        Label("Utilisateurs bloqués", systemImage: "hand.raised.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showDeleteSheet = true
                    } label: {
                        Text("Supprimer mon compte")
                            .font(.footnote.weight(.semibold))
                    }
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
        .sheet(isPresented: $showBlocked) {
            BlockedUsersSheet(store: store)
        }
    }

    /// Barre d'onglets social : icône + libellé, plus lisible qu'un segmented,
    /// avec une pastille rouge sur Messages dès qu'un groupe a du non-lu.
    private var socialTabBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(SocialTab.allCases) { t in
                let isSelected = tab == t
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                    HapticManager.lightImpact()
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: t.icon)
                                .font(.subheadline.weight(.semibold))
                            if t == .groups && hasUnreadGroups {
                                Circle().fill(.red).frame(width: 7, height: 7).offset(x: 7, y: -3)
                            }
                        }
                        Text(t.title).font(.caption2.weight(.semibold)).lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? .white : Color.accentDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .fill(isSelected ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.accentDeep.opacity(0.10)))
                    )
                }
                .buttonStyle(.plain)
            }
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
    /// Confirmation éphémère après un applaudissement.
    @State private var cheerToast: String?
    /// Amis à qui je viens d'applaudir (pour l'animation de l'icône).
    @State private var cheered: Set<String> = []

    /// Les encouragements reçus. Le bouton « Merci ! » vide la boîte serveur.
    private var receivedCheersCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                Text("👏").font(.title2)
                Text(store.cheers.count == 1
                     ? L("Tu as reçu un encouragement !")
                     : L("Tu as reçu \(store.cheers.count) encouragements !"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentDeep)
                Spacer(minLength: 0)
            }
            ForEach(store.cheers.prefix(5)) { cheer in
                HStack(spacing: 6) {
                    Image(systemName: "hands.clap.fill")
                        .font(.caption2).foregroundStyle(Color.steadyFlame)
                    Text(L("\(cheer.fromUsername) t'encourage"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(cheer.date, style: .relative)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Button {
                HapticManager.success()
                Task { await store.clearCheers() }
            } label: {
                Text("Merci !")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(Capsule().fill(Color.accentGradient))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steadyCard()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Encouragements reçus : sans ça, un 👏 partirait dans le vide.
            if !store.cheers.isEmpty {
                receivedCheersCard
            }

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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                _ = cheered.insert(friend.id)
                            }
                            cheerToast = L("👏 Bravo envoyé à \(friend.username) !")
                            Task { await store.cheer(friend) }
                        } label: {
                            Image(systemName: "hands.clap.fill")
                                .foregroundStyle(cheered.contains(friend.id) ? Color.steadyFlame : Color.accentDeep)
                                .scaleEffect(cheered.contains(friend.id) ? 1.25 : 1.0)
                                .symbolEffect(.bounce, value: cheered.contains(friend.id))
                        }
                        .buttonStyle(.plain)
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

            // Confirmation éphémère de l'applaudissement.
            if let cheerToast {
                Text(cheerToast)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(Color.steadyFlame))
                    .transition(.scale.combined(with: .opacity))
                    .task(id: cheerToast) {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { self.cheerToast = nil }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cheerToast)
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
            // Un seul classement : les validations (le plus parlant et le plus juste).
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.accentDeep)
                Text("Classement des validations").font(.subheadline.weight(.bold))
                Spacer()
            }

            ForEach(store.leaderboard) { entry in
                HStack(spacing: Theme.Spacing.md) {
                    rankBadge(entry.rank)
                    Image(systemName: entry.profile.avatarSymbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.accentGradient))
                    // Toujours le vrai pseudo (même pour soi) ; un petit « toi »
                    // indique ta ligne, en plus du surlignage.
                    Text(entry.profile.username)
                        .font(.subheadline.weight(entry.isMe ? .bold : .semibold))
                        .lineLimit(1)
                    if entry.isMe {
                        Text("toi")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.accentDeep)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Color.brandAccent.opacity(0.25)))
                    }
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
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {
                showCreate = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Créer un groupe")
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
            .sheet(isPresented: $showCreate) {
                CreateGroupSheet(store: store)
            }

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
                            if store.hasUnread(group) {
                                Circle().fill(Color.accentDeep).frame(width: 10, height: 10)
                                    .accessibilityLabel("Nouveaux messages")
                            }
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

// MARK: - Création de groupe

private struct CreateGroupSheet: View {
    var store: SocialStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "person.3.fill"
    @State private var selected: Set<String> = []
    @State private var creating = false
    @State private var failed = false

    private static let icons = ["person.3.fill", "house.fill", "figure.run", "dumbbell.fill",
                                "book.fill", "leaf.fill", "flame.fill", "star.fill"]

    private var canCreate: Bool { name.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Nom
                    TextField("Nom du groupe (ex. Famille, Running Club…)", text: $name)
                        .padding(Theme.Spacing.md)
                        .steadyCard(cornerRadius: Theme.Radius.md)

                    // Icône
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: Theme.Spacing.sm) {
                        ForEach(Self.icons, id: \.self) { symbol in
                            Button {
                                icon = symbol
                                HapticManager.lightImpact()
                            } label: {
                                Image(systemName: symbol)
                                    .font(.subheadline)
                                    .foregroundStyle(icon == symbol ? .white : Color.accentDeep)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(icon == symbol ? Color.accentDeep : Color.accentDeep.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Membres
                    if store.friends.isEmpty {
                        Text("Tu pourras inviter des amis une fois que tu en auras ajouté (onglet Amis).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Ajouter des amis au groupe")
                            .font(.subheadline.weight(.semibold))
                        ForEach(store.friends) { friend in
                            Button {
                                if selected.contains(friend.id) { selected.remove(friend.id) }
                                else { selected.insert(friend.id) }
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: friend.avatarSymbol)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.accentGradient))
                                    Text(friend.username)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: selected.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(friend.id) ? Color.accentDeep : .secondary)
                                }
                                .padding(Theme.Spacing.md)
                                .steadyCard(cornerRadius: Theme.Radius.md)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if failed {
                        Label("Création impossible. Vérifie ta connexion et réessaie.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    // Créer
                    Button {
                        creating = true
                        failed = false
                        let members = store.friends.filter { selected.contains($0.id) }
                        Task {
                            let ok = await store.createGroup(name: name.trimmingCharacters(in: .whitespaces), icon: icon, friends: members)
                            creating = false
                            if ok { HapticManager.success(); dismiss() } else { failed = true }
                        }
                    } label: {
                        Group {
                            if creating { ProgressView().tint(.white) }
                            else { Text("Créer le groupe").font(.headline) }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(canCreate ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.secondary.opacity(0.3))))
                    }
                    .disabled(!canCreate || creating)
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Nouveau groupe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Membres du groupe

private struct GroupMembersSheet: View {
    var store: SocialStore
    let group: SocialGroup
    @Environment(\.dismiss) private var dismiss

    @State private var profiles: [UserProfile] = []
    @State private var loading = true
    @State private var showAdd = false

    /// Amis pas encore membres du groupe (candidats à l'ajout).
    private var addableFriends: [UserProfile] {
        let memberIDs = Set(profiles.map(\.id))
        return store.friends.filter { !memberIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if loading {
                        ProgressView().padding(.top, Theme.Spacing.xl)
                    } else if profiles.isEmpty {
                        Text("Impossible de charger les membres. Réessaie plus tard.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, Theme.Spacing.xl)
                    } else {
                        ForEach(profiles) { member in
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: member.avatarSymbol)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.accentGradient))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(member.username)
                                        .font(.subheadline.weight(.bold))
                                    HStack(spacing: 10) {
                                        Label("Niv. \(member.level)", systemImage: "star.fill")
                                        Label("\(member.streak) j", systemImage: "flame.fill")
                                        Label("\(member.score)", systemImage: "bolt.fill")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(Theme.Spacing.md)
                            .steadyCard()
                        }
                    }

                    // Ajouter une personne au groupe (parmi mes amis non-membres).
                    if !loading {
                        Button {
                            showAdd = true
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "person.badge.plus")
                                Text("Ajouter des amis")
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
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle(L("Membres (\(profiles.count))"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddGroupMembersSheet(store: store, group: group, candidates: addableFriends) {
                    // Recharge la liste après ajout.
                    Task { profiles = await store.members(group) }
                }
            }
            .task {
                profiles = await store.members(group)
                loading = false
            }
        }
    }
}

// MARK: - Ajouter des membres à un groupe existant

private struct AddGroupMembersSheet: View {
    var store: SocialStore
    let group: SocialGroup
    let candidates: [UserProfile]
    var onAdded: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String> = []
    @State private var working = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if candidates.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "person.2.slash").font(.system(size: 40)).foregroundStyle(.secondary)
                            Text("Tous tes amis sont déjà dans ce groupe")
                                .font(.headline).multilineTextAlignment(.center)
                            Text("Ajoute d'abord d'autres amis dans l'onglet Amis.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .padding(.top, Theme.Spacing.xl)
                    } else {
                        ForEach(candidates) { friend in
                            Button {
                                if selected.contains(friend.id) { selected.remove(friend.id) }
                                else { selected.insert(friend.id) }
                                HapticManager.lightImpact()
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: friend.avatarSymbol)
                                        .font(.body.weight(.semibold)).foregroundStyle(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Color.accentGradient))
                                    Text(friend.username).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
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

                    if failed {
                        Label("Ajout impossible. Vérifie ta connexion et réessaie.", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Ajouter au groupe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                if !candidates.isEmpty {
                    Button {
                        let chosen = candidates.filter { selected.contains($0.id) }
                        working = true; failed = false
                        Task {
                            let ok = await store.addMembers(chosen, to: group)
                            working = false
                            if ok { HapticManager.success(); onAdded(); dismiss() } else { failed = true }
                        }
                    } label: {
                        Group {
                            if working { ProgressView().tint(.white) }
                            else { Text(selected.isEmpty ? L("Choisis au moins un ami") : L("Ajouter (\(selected.count))")).font(.headline) }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(selected.isEmpty ? AnyShapeStyle(Color.secondary.opacity(0.3)) : AnyShapeStyle(Color.accentGradient)))
                    }
                    .disabled(selected.isEmpty || working)
                    .padding(.horizontal).padding(.bottom, Theme.Spacing.sm)
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
    @State private var showMembers = false

    // Modération (règle App Store 1.2) : règles acceptées une fois, puis
    // signalement et blocage accessibles sur chaque message reçu.
    @AppStorage("steady_ugc_rules_accepted") private var rulesAccepted = false
    @State private var showRules = false
    @State private var pendingSend: String?
    @State private var reportTarget: ChatMessage?
    @State private var blockTarget: ChatMessage?
    @State private var moderationAlert: String?

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
                    attemptSend()
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMembers = true
                } label: {
                    Image(systemName: "person.2")
                        .foregroundStyle(Color.accentDeep)
                }
                .accessibilityLabel("Voir les membres du groupe")
            }
        }
        .sheet(isPresented: $showMembers) {
            GroupMembersSheet(store: store, group: group)
        }
        .sheet(isPresented: $showRules) {
            CommunityRulesSheet {
                rulesAccepted = true
                if let text = pendingSend {
                    pendingSend = nil
                    draft = ""
                    Task { await performSend(text) }
                }
            }
        }
        // Choix du motif de signalement.
        .confirmationDialog("Signaler ce message",
                            isPresented: Binding(get: { reportTarget != nil },
                                                 set: { if !$0 { reportTarget = nil } }),
                            titleVisibility: .visible) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) {
                    guard let msg = reportTarget else { return }
                    reportTarget = nil
                    Task {
                        await store.report(message: msg, in: group, reason: reason)
                        moderationAlert = L("Merci. Le signalement a été transmis, nous l'examinons sous 24 h.")
                    }
                }
            }
            Button("Annuler", role: .cancel) { reportTarget = nil }
        }
        // Confirmation de blocage.
        .alert("Bloquer cette personne ?",
               isPresented: Binding(get: { blockTarget != nil },
                                    set: { if !$0 { blockTarget = nil } })) {
            Button("Bloquer", role: .destructive) {
                guard let msg = blockTarget else { return }
                blockTarget = nil
                Task {
                    await store.block(msg.authorUID)
                    messages = await store.messages(group)
                }
            }
            Button("Annuler", role: .cancel) { blockTarget = nil }
        } message: {
            Text("Tu ne verras plus ses messages ni son profil. Tu pourras le débloquer dans Communauté.")
        }
        .alert("Communauté", isPresented: Binding(get: { moderationAlert != nil },
                                                  set: { if !$0 { moderationAlert = nil } })) {
            Button("OK", role: .cancel) { moderationAlert = nil }
        } message: {
            Text(moderationAlert ?? "")
        }
        .task {
            messages = await store.messages(group)
            store.markRead(group)
        }
    }

    // MARK: - Envoi (filtre + acceptation des règles)

    private func attemptSend() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // Première publication : l'utilisateur doit accepter les règles (règle 1.2).
        guard rulesAccepted else {
            pendingSend = text
            showRules = true
            return
        }
        draft = ""
        Task { await performSend(text) }
    }

    private func performSend(_ text: String) async {
        if let updated = await store.send(text, to: group) {
            messages = updated
            store.markRead(group)   // mon propre message ne me marque pas « non lu »
        } else {
            // Refusé par le filtre : on rend le texte pour permettre la correction.
            draft = text
            moderationAlert = ContentModeration.rejectionMessage
        }
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
        // Signalement / blocage accessibles sur les messages reçus (règle 1.2).
        .contextMenu {
            if !msg.isMine {
                Button {
                    reportTarget = msg
                } label: {
                    Label("Signaler", systemImage: "flag")
                }
                Button(role: .destructive) {
                    blockTarget = msg
                } label: {
                    Label("Bloquer", systemImage: "hand.raised.fill")
                }
            }
        }
    }
}

// MARK: - Utilisateurs bloqués (débloquer)

/// Bloquer sans pouvoir débloquer serait un piège : cet écran rend l'action
/// réversible et donne à l'utilisateur la maîtrise de sa liste.
private struct BlockedUsersSheet: View {
    var store: SocialStore
    @Environment(\.dismiss) private var dismiss
    @State private var blocked: [UserProfile] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if loading {
                        ProgressView().padding(.top, Theme.Spacing.xl)
                    } else if blocked.isEmpty {
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 40)).foregroundStyle(.secondary)
                            Text("Personne n'est bloqué").font(.headline)
                            Text("Tu peux bloquer quelqu'un depuis un message, en appuyant longuement dessus.")
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Theme.Spacing.xl)
                    } else {
                        ForEach(blocked) { user in
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: user.avatarSymbol)
                                    .font(.headline).foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(Circle().fill(Color.secondary.gradient))
                                Text(user.username).font(.subheadline.weight(.semibold))
                                Spacer()
                                Button {
                                    Task {
                                        await store.unblock(user.id)
                                        blocked = await store.blockedUsers()
                                    }
                                } label: {
                                    Text("Débloquer")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.accentDeep)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(Color.accentDeep.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .steadyCard(cornerRadius: Theme.Radius.md)
                        }
                    }
                }
                .padding(.horizontal).padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Utilisateurs bloqués")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .task {
                blocked = await store.blockedUsers()
                loading = false
            }
        }
    }
}

// MARK: - Règles de la communauté (acceptation obligatoire avant de publier)

/// Apple (règle 1.2) exige que l'utilisateur accepte des conditions de tolérance
/// zéro envers les contenus offensants AVANT de pouvoir publier.
private struct CommunityRulesSheet: View {
    var onAccept: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.accentGradient)
                        Text("Règles de la communauté")
                            .font(.title2.weight(.bold))
                        Text("Steady applique une tolérance zéro envers les contenus offensants et les comportements abusifs.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        rule("hand.thumbsup.fill", "Reste bienveillant",
                             "On est là pour s'encourager, pas pour se juger.")
                        rule("nosign", "Aucun contenu offensant",
                             "Harcèlement, propos haineux, contenu sexuel ou spam sont interdits.")
                        rule("flag.fill", "Signale ce qui dérange",
                             "Appuie longuement sur un message pour le signaler. Nous examinons sous 24 h.")
                        rule("person.crop.circle.badge.xmark", "Bloque qui tu veux",
                             "Un utilisateur bloqué disparaît complètement de ton fil.")
                    }

                    Text("Les comptes qui enfreignent ces règles sont suspendus.")
                        .font(.caption).foregroundStyle(.secondary)

                    Button {
                        onAccept()
                        dismiss()
                    } label: {
                        Text("J'accepte les règles")
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(Color.accentGradient))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal).padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Avant de publier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private func rule(_ icon: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentDeep)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.brandAccent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
