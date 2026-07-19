import SwiftUI

/// Bulles de catégories, manipulables directement sur l'écran Habitudes :
/// - **tap** : filtrer la liste sur la catégorie (re-tap = tout afficher) ;
/// - **appui long puis glisser** : déplacer la bulle (position mémorisée) ;
/// - **pincer** : agrandir / réduire la bulle (taille mémorisée) ;
/// - **glisser une habitude dessus** : la ranger dans cette catégorie.
///
/// Plus une catégorie contient d'habitudes (et de priorités hautes), plus sa
/// bulle est grosse par défaut — le pincement vient moduler cette base.
struct CategoryBubblesView: View {
    let habits: [Habit]
    @Binding var selected: HabitCategory?
    /// Appelé quand une habitude est déposée sur une bulle.
    var onAssign: (UUID, HabitCategory) -> Void

    /// Disposition personnalisée (offset + échelle) par catégorie, persistée.
    @AppStorage("steady_bubble_layout") private var layoutJSON = "{}"
    @State private var layout: [String: BubbleLayout] = [:]

    /// Déplacement en cours : (catégorie, translation live).
    @GestureState private var drag: (category: HabitCategory, translation: CGSize)? = nil
    /// Bulle actuellement survolée par un drop d'habitude.
    @State private var dropTarget: HabitCategory?

    private struct BubbleLayout: Codable {
        var dx: Double = 0
        var dy: Double = 0
        var scale: Double = 1
    }

    // MARK: - Poids / tailles

    private var weights: [(category: HabitCategory, weight: Int, count: Int)] {
        HabitCategory.allCases.compactMap { category in
            let members = habits.filter { $0.category == category }
            guard !members.isEmpty else { return nil }
            let weight = members.count + members.filter { $0.priority == .high }.count
            return (category, weight, members.count)
        }
        .sorted { $0.weight > $1.weight }
    }

    /// Plage volontairement large pour un vrai contraste visuel : une catégorie
    /// à 1 habitude est nettement petite, une grosse catégorie très visible.
    private func baseDiameter(_ weight: Int) -> CGFloat { min(140, 46 + CGFloat(weight - 1) * 17) }

    private func scale(for c: HabitCategory) -> CGFloat { CGFloat(layout[c.rawValue]?.scale ?? 1) }

    private func diameter(_ entry: (category: HabitCategory, weight: Int, count: Int)) -> CGFloat {
        baseDiameter(entry.weight) * scale(for: entry.category)
    }

    private var isCustomized: Bool {
        layout.values.contains { $0.dx != 0 || $0.dy != 0 || $0.scale != 1 }
    }

    // MARK: - Disposition automatique (repli, avant déplacement manuel)

    /// Centres de base : on remplit de gauche à droite, on passe à la ligne
    /// quand la largeur est dépassée.
    private func baseCenters(width: CGFloat) -> ([HabitCategory: CGPoint], CGFloat) {
        var centers: [HabitCategory: CGPoint] = [:]
        let gap: CGFloat = 12
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for entry in weights {
            let d = diameter(entry)
            if x + d > width && x > 0 { x = 0; y += rowH + gap; rowH = 0 }
            centers[entry.category] = CGPoint(x: x + d / 2, y: y + d / 2)
            x += d + gap
            rowH = max(rowH, d)
        }
        return (centers, y + rowH)
    }

    private func center(_ c: HabitCategory, base: [HabitCategory: CGPoint], canvas: CGSize) -> CGPoint {
        let b = base[c] ?? CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let l = layout[c.rawValue] ?? BubbleLayout()
        var p = CGPoint(x: b.x + l.dx, y: b.y + l.dy)
        if drag?.category == c {
            p.x += drag!.translation.width
            p.y += drag!.translation.height
        }
        // On garde la bulle dans le cadre.
        let r = (diameter((weights.first { $0.category == c }!)) ) / 2
        p.x = min(max(r, p.x), canvas.width - r)
        p.y = min(max(r, p.y), canvas.height - r)
        return p
    }

    // MARK: - Corps

    var body: some View {
        if weights.count > 1 {
            GeometryReader { geo in
                let (base, contentH) = baseCenters(width: geo.size.width)
                let canvas = CGSize(width: geo.size.width, height: max(150, contentH + 28))
                ZStack(alignment: .topLeading) {
                    ForEach(weights, id: \.category) { entry in
                        bubble(entry)
                            .position(center(entry.category, base: base, canvas: canvas))
                            // La bulle déplacée passe au-dessus des autres.
                            .zIndex(drag?.category == entry.category ? 1 : 0)
                    }
                }
                .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
                .overlay(alignment: .topTrailing) {
                    if isCustomized { resetButton }
                }
            }
            .frame(height: canvasHeight)
            .onAppear(perform: loadLayout)
        }
    }

    /// Hauteur réservée dans la liste (recalculée à partir du contenu de base).
    private var canvasHeight: CGFloat {
        // Largeur inconnue ici : on estime avec une largeur d'écran typique.
        let (_, h) = baseCenters(width: UIScreen.main.bounds.width - 32)
        return max(150, h + 28)
    }

    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { layout = [:] }
            saveLayout()
            HapticManager.lightImpact()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(7)
                .background(Circle().fill(Color.steadyCard))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Réinitialiser la disposition")
    }

    // MARK: - Une bulle

    private func bubble(_ entry: (category: HabitCategory, weight: Int, count: Int)) -> some View {
        let c = entry.category
        let isSelected = selected == c
        let isDropTarget = dropTarget == c
        let size = diameter(entry)
        return VStack(spacing: 2) {
            Image(systemName: c.icon)
                .font(.system(size: size * 0.2, weight: .semibold))
            Text(c.titleText)
                .font(.system(size: max(11, size * 0.15), weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(entry.count)")
                .font(.system(size: max(11, size * 0.13), weight: .semibold))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .frame(width: size, height: size)
        .background(Circle().fill(c.color.gradient))
        .overlay(
            Circle().strokeBorder(.white.opacity(isDropTarget ? 1 : (isSelected ? 0.9 : 0)),
                                  lineWidth: isDropTarget ? 4 : 3)
        )
        .shadow(color: c.color.opacity(isSelected || isDropTarget ? 0.5 : 0.25),
                radius: isSelected || isDropTarget ? 12 : 5, y: 3)
        .scaleEffect(scaleEffect(for: c, selected: isSelected, dropTarget: isDropTarget))
        .opacity(selected == nil || isSelected ? 1 : 0.55)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTarget)
        // Tap = filtrer.
        .onTapGesture {
            HapticManager.lightImpact()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                selected = isSelected ? nil : c
            }
        }
        // Glisser = déplacer. Gesture normal (pas highPriority) : sinon il
        // « mange » le tap et le filtrage ne se déclenche plus.
        .gesture(moveGesture(c))
        // Pincer = agrandir / réduire.
        .simultaneousGesture(pinchGesture(c))
        // Déposer une habitude dessus = la catégoriser.
        .dropDestination(for: String.self) { items, _ in
            guard let idStr = items.first, let id = UUID(uuidString: idStr) else { return false }
            onAssign(id, c)
            return true
        } isTargeted: { hovering in
            dropTarget = hovering ? c : (dropTarget == c ? nil : dropTarget)
        }
        .accessibilityLabel("\(c.titleText), \(entry.count) habitudes")
        .accessibilityHint(isSelected ? "Retirer le filtre" : "Filtrer sur cette catégorie")
    }

    private func scaleEffect(for c: HabitCategory, selected: Bool, dropTarget: Bool) -> CGFloat {
        if drag?.category == c { return 1.18 }   // « soulèvement » pendant le déplacement
        if dropTarget { return 1.15 }
        if self.selected == nil || selected { return 1 }
        return 0.85
    }

    // MARK: - Gestes

    private func moveGesture(_ c: HabitCategory) -> some Gesture {
        // Glissement direct, sans appui long : réactif tout de suite. Une distance
        // minimale de 12 pt distingue un vrai glissement d'un simple tap — en
        // dessous, rien ne bouge et c'est `onTapGesture` (le filtre) qui agit.
        DragGesture(minimumDistance: 12)
            .updating($drag) { value, state, _ in
                state = (c, value.translation)
            }
            .onEnded { value in
                var l = layout[c.rawValue] ?? BubbleLayout()
                l.dx += value.translation.width
                l.dy += value.translation.height
                layout[c.rawValue] = l
                saveLayout()
                HapticManager.lightImpact()
            }
    }

    private func pinchGesture(_ c: HabitCategory) -> some Gesture {
        MagnifyGesture()
            .onEnded { value in
                var l = layout[c.rawValue] ?? BubbleLayout()
                l.scale = min(2.2, max(0.5, l.scale * value.magnification))   // plage large
                layout[c.rawValue] = l
                saveLayout()
                HapticManager.lightImpact()
            }
    }

    // MARK: - Persistance

    private func loadLayout() {
        guard let data = layoutJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: BubbleLayout].self, from: data)
        else { return }
        layout = decoded
    }

    private func saveLayout() {
        if let data = try? JSONEncoder().encode(layout), let str = String(data: data, encoding: .utf8) {
            layoutJSON = str
        }
    }
}
