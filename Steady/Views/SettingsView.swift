import SwiftUI

struct SettingsView: View {
    @Bindable var store: HabitStore
    @State private var showPremiumSheet = false

    private var notif: NotificationManager { NotificationManager.shared }
    private var isPremium: Bool { store.storeManager.isPremium }

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(spacing: 0) {
                SteadyTitle("Paramètres")
                VStack(spacing: Theme.Spacing.lg) {
                    premiumBanner
                    notificationsSection
                    themeSection
                    languageSection
                    aboutSection
                }
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
              }
            }
            .background(AnimatedBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView(storeManager: store.storeManager)
            }
        }
    }

    // MARK: - Bannière Premium

    @ViewBuilder
    private var premiumBanner: some View {
        if isPremium {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium actif").font(.headline).foregroundStyle(.white)
                    Text("Merci de soutenir Steady 💚")
                        .font(.caption).foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Color.accentGradient))
            .shadow(color: Color.brandAccent.opacity(0.3), radius: 12, y: 6)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill").font(.title2)
                    Text("Steady Premium").font(.title3.weight(.bold))
                    Spacer()
                }
                .foregroundStyle(.white)

                Text("Habitudes illimitées, thèmes de couleur et statistiques avancées.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))

                Button {
                    showPremiumSheet = true
                } label: {
                    Text("Débloquer")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.accentDeep)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white))
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Color.accentGradient))
            .shadow(color: Color.brandAccent.opacity(0.35), radius: 14, y: 8)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Notifications")

            VStack(spacing: Theme.Spacing.md) {
                Toggle(isOn: Binding(
                    get: { notif.isEnabled },
                    set: { notif.isEnabled = $0 }
                )) {
                    Label {
                        Text("Activer les rappels")
                    } icon: {
                        rowIcon("bell.fill")
                    }
                }
                .tint(Color.accentDeep)

                if notif.isEnabled {
                    Divider()
                    Toggle(isOn: Binding(
                        get: { notif.dailyReminderEnabled },
                        set: { notif.dailyReminderEnabled = $0 }
                    )) {
                        Label { Text("Rappel quotidien") } icon: { rowIcon("sun.max.fill") }
                    }
                    .tint(Color.accentDeep)

                    if notif.dailyReminderEnabled {
                        DatePicker(
                            selection: Binding(
                                get: { notif.dailyReminderTime },
                                set: { newTime in
                                    notif.dailyReminderTime = newTime
                                    notif.rescheduleAll(premium: isPremium)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        ) {
                            Label { Text("Heure") } icon: { rowIcon("clock.fill") }
                        }
                    }

                    Text("Un coup de pouce doux une fois par jour. Pour un rappel précis, règle-le dans le détail de chaque habitude. Ton bilan arrive aussi chaque dimanche soir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Theme.Spacing.lg)
            .steadyCard()
        }
    }

    // MARK: - Thème

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Thème".uppercased())
                if !isPremium {
                    Image(systemName: "lock.fill").font(.caption2)
                    Text("Premium").font(.caption2)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(ThemeManager.Palette.allCases) { palette in
                        Button {
                            if isPremium {
                                withAnimation { ThemeManager.shared.palette = palette }
                                HapticManager.lightImpact()
                            } else {
                                showPremiumSheet = true
                            }
                        } label: {
                            paletteSwatch(palette)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .steadyCard()
        }
    }

    private func paletteSwatch(_ palette: ThemeManager.Palette) -> some View {
        let selected = ThemeManager.shared.palette == palette
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(palette.gradient).frame(width: 46, height: 46)
                if selected {
                    Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                } else if !isPremium {
                    Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.white.opacity(0.9))
                }
            }
            .overlay(Circle().strokeBorder(Color.primary.opacity(selected ? 0.85 : 0), lineWidth: 3))
            Text(palette.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Langue

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Langue")
            HStack {
                Label { Text("Langue") } icon: { rowIcon("globe") }
                Spacer()
                Picker("", selection: Binding(
                    get: { LocalizationManager.shared.language },
                    set: { LocalizationManager.shared.language = $0 }
                )) {
                    ForEach(LocalizationManager.Language.allCases) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
                .labelsHidden()
                .tint(Color.accentDeep)
            }
            .padding(Theme.Spacing.lg)
            .steadyCard()
        }
    }

    // MARK: - À propos

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Application")
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Label { Text("Version") } icon: { rowIcon("info.circle.fill") }
                    Spacer()
                    Text(appVersion).foregroundStyle(.secondary)
                }
                Divider()
                Link(destination: AppLinks.privacyPolicy) {
                    settingsLinkRow("Politique de confidentialité", icon: "hand.raised.fill")
                }
                Divider()
                Link(destination: AppLinks.termsOfUse) {
                    settingsLinkRow("Conditions d'utilisation", icon: "doc.text.fill")
                }
                Divider()
                Button {
                    Task { await store.storeManager.restorePurchases() }
                } label: {
                    settingsLinkRow("Restaurer les achats", icon: "arrow.counterclockwise")
                }
            }
            .padding(Theme.Spacing.lg)
            .steadyCard()
        }
    }

    private func settingsLinkRow(_ title: LocalizedStringKey, icon: String) -> some View {
        HStack {
            Label { Text(title).foregroundStyle(.primary) } icon: { rowIcon(icon) }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Briques

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentDeep)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.brandAccent.opacity(0.15)))
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
