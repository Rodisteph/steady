import SwiftUI

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    var store: HabitStore
    let currentCount: Int

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var showPremiumSheet = false

    private let icons = [
        "star.fill", "book.fill", "figure.run", "drop.fill",
        "moon.fill", "sun.max.fill", "heart.fill", "bolt.fill",
        "leaf.fill", "flame.fill", "brain.head.profile", "dumbbell.fill",
        "fork.knife", "cup.and.saucer.fill", "pencil", "music.note"
    ]

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
                        iconGrid
                    }

                    if !store.storeManager.isPremium {
                        freeQuotaBanner
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Color.steadyBackground.ignoresSafeArea())
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
                .background(Circle().fill(Color.steadySageGradient))
                .shadow(color: Color.steadySage.opacity(0.35), radius: 12, y: 6)
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

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.md), count: 4), spacing: Theme.Spacing.md) {
            ForEach(icons, id: \.self) { icon in
                let isSelected = selectedIcon == icon
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        selectedIcon = icon
                    }
                    HapticManager.lightImpact()
                } label: {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .fill(isSelected ? AnyShapeStyle(Color.steadySageGradient) : AnyShapeStyle(Color.steadyCard))
                        )
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Icône \(icon)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
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
                .foregroundStyle(Color.steadySageDeep)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.steadySage.opacity(0.12))
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
