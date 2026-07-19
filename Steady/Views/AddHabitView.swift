import SwiftUI

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    var store: HabitStore
    let currentCount: Int

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var showPremiumSheet = false
    @State private var showIconPicker = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// Habitudes courantes proposées : un tap remplit le nom + l'icône.
    private static let suggestions: [(name: String, icon: String)] = [
        (L("Boire de l'eau"), "drop.fill"),
        (L("Méditer"), "brain.head.profile"),
        (L("Lire 10 pages"), "book.fill"),
        (L("Courir"), "figure.run"),
        (L("Faire du sport"), "dumbbell.fill"),
        (L("Marcher 30 min"), "figure.walk"),
        (L("Étirements"), "figure.flexibility"),
        (L("Gratitude"), "heart.fill"),
        (L("Écrire mon journal"), "book.closed.fill"),
        (L("Se coucher tôt"), "bed.double.fill"),
        (L("Pas d'écran le soir"), "iphone.slash"),
        (L("Manger un fruit"), "fork.knife"),
        (L("Apprendre une langue"), "character.book.closed.fill"),
        (L("Ranger 10 min"), "house.fill"),
        (L("Prendre mes vitamines"), "pills.fill"),
        (L("Réviser 1h"), "pencil.and.ruler.fill"),
        (L("Faire mon lit"), "bed.double.fill"),
        (L("10 min de soleil"), "sun.max.fill"),
        (L("Fil dentaire"), "mouth.fill"),
        (L("Prendre l'air"), "leaf.fill"),
        (L("Cuisiner maison"), "frying.pan.fill"),
        (L("Économiser"), "eurosign.circle.fill"),
        (L("Appeler un proche"), "phone.fill"),
        (L("Faire une pause écran"), "eye.fill"),
        (L("Respiration profonde"), "wind")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    livePreview

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        sectionTitle("Nom de l'habitude")
                        TextField("Ex : Lire 10 pages", text: $name)
                            .autocorrectionDisabled()
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(Color.steadyCard)
                            )
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        sectionTitle("Suggestions")
                        suggestionsGrid
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        sectionTitle("Icône")
                        iconChooser
                    }

                    if !store.storeManager.isPremium {
                        freeQuotaBanner
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(AnimatedBackground(animated: false))
            .navigationTitle("Nouvelle habitude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { addHabit() }
                        .disabled(trimmedName.isEmpty)
                        .bold()
                }
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView(storeManager: store.storeManager, context: .habitLimit)
            }
        }
    }

    // MARK: - Sous-vues

    private var livePreview: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: selectedIcon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(Circle().fill(Color.accentGradient))
                .shadow(color: Color.brandAccent.opacity(0.35), radius: 12, y: 6)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: selectedIcon)

            Text(trimmedName.isEmpty ? "Votre habitude" : trimmedName)
                .font(.title3.weight(.bold))
                .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var suggestionsGrid: some View {
        let cols = [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.sm)]
        return LazyVGrid(columns: cols, spacing: Theme.Spacing.sm) {
            ForEach(Self.suggestions, id: \.name) { s in
                Button {
                    name = s.name
                    selectedIcon = s.icon
                    HapticManager.lightImpact()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: s.icon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.accentDeep)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.accentDeep.opacity(0.12)))
                        Text(s.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(name == s.name ? Color.brandAccent.opacity(0.18) : Color.steadyCard)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var iconChooser: some View {
        Button {
            showIconPicker = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: selectedIcon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.accentGradient))
                Text("Choisir une icône")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Color.steadyCard))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selection: $selectedIcon)
        }
    }

    private var freeQuotaBanner: some View {
        HStack {
            Text("Gratuit : \(currentCount)/3 habitudes")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Passer à Premium") { showPremiumSheet = true }
                .font(.footnote.bold())
                .foregroundStyle(Color.accentDeep)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.brandAccent.opacity(0.12))
        )
    }

    private func addHabit() {
        guard store.canAddHabit(currentCount: currentCount) else {
            showPremiumSheet = true
            return
        }

        try? store.addHabit(name: trimmedName, icon: selectedIcon)
        HapticManager.lightImpact()
        dismiss()
    }
}
