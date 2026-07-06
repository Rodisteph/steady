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
                PremiumView(storeManager: store.storeManager)
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
