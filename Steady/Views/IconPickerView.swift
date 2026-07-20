import SwiftUI

/// Sélecteur d'icônes : recherche, catégories, favoris, aperçu.
struct IconPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    /// `nil` = onglet Favoris.
    @State private var category: IconCategory? = .popular
    private var favorites = IconFavorites.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 5)

    /// Initialiseur explicite : sans lui, les propriétés `private` de cette vue
    /// rendent l'initialiseur automatique privé, et les autres fichiers ne
    /// peuvent plus construire le sélecteur. Il doit vivre ICI (même fichier)
    /// car `_selection` (le stockage du @Binding) est privé. Être dans le corps
    /// de la struct remplace l'init memberwise — donc un seul init, sans ambiguïté.
    init(selection: Binding<String>) {
        self._selection = selection
    }

    private var symbols: [String] {
        let trimmed = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty {
            return IconCategory.allSymbols.filter { $0.contains(trimmed) }
        }
        if let category {
            return category.symbols
        }
        return favorites.symbols.sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                preview
                categoryBar
                grid
            }
            .background(AnimatedBackground())
            .navigationTitle("Icône")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: Text("Rechercher"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
        }
    }

    private var preview: some View {
        Image(systemName: selection)
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 76, height: 76)
            .background(Circle().fill(Color.accentGradient))
            .padding(.top, Theme.Spacing.sm)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                chip(title: "Favoris", isOn: category == nil && search.isEmpty) { category = nil }
                ForEach(IconCategory.allCases) { cat in
                    chip(title: cat.title, isOn: category == cat && search.isEmpty) { category = cat }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(title: LocalizedStringKey, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? .white : .primary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(isOn ? AnyShapeStyle(Color.accentDeep) : AnyShapeStyle(Color.steadyCard)))
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        ScrollView {
            if symbols.isEmpty {
                Text("Aucune icône")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    ForEach(symbols, id: \.self) { symbol in
                        cell(symbol)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }

    private func cell(_ symbol: String) -> some View {
        let isSelected = selection == symbol
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { selection = symbol }
            HapticManager.lightImpact()
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.steadyCard))
                )
                .overlay(alignment: .topTrailing) {
                    if favorites.contains(symbol) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.steadyFlame)
                            .padding(4)
                    }
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                favorites.toggle(symbol)
            } label: {
                Label(favorites.contains(symbol) ? "Retirer des favoris" : "Ajouter aux favoris",
                      systemImage: favorites.contains(symbol) ? "star.slash" : "star")
            }
        }
    }
}
