import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var editingEntry: JournalEntry?
    @State private var showNewEntry = false
    @State private var staggerDone = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SteadyTitle("Journal")
                Group {
                    if entries.isEmpty {
                        ScrollView { emptyState }
                    } else {
                        List {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                Button { editingEntry = entry } label: {
                                    JournalCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .appearStagger(index, enabled: !staggerDone)
                                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: 16, bottom: Theme.Spacing.sm, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(entry)
                                    } label: {
                                        Label("Supprimer", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .background(AnimatedBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewEntry = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .foregroundStyle(Color.accentDeep)
                    }
                    .accessibilityLabel("Nouvelle note")
                }
            }
            .sheet(isPresented: $showNewEntry) { JournalEditorView(entry: nil) }
            .sheet(item: $editingEntry) { entry in JournalEditorView(entry: entry) }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { staggerDone = true }
            }
        }
    }

    private func delete(_ entry: JournalEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        HapticManager.lightImpact()
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentGradient)
            Text("Ton journal")
                .font(.title3.weight(.bold))
            Text("Quelques lignes le soir suffisent. Note un ressenti, une victoire, une pensée.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button { showNewEntry = true } label: {
                Label("Écrire ce soir", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.accentGradient))
            }
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Carte d'une note

struct JournalCard: View {
    let entry: JournalEntry

    private var moodEmoji: String? {
        guard let m = entry.mood, let mood = Mood(rawValue: m) else { return nil }
        return mood.emoji
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            ZStack {
                Circle().fill(Color.brandAccent.opacity(0.15)).frame(width: 42, height: 42)
                if let moodEmoji {
                    Text(moodEmoji).font(.title3)
                } else {
                    Image(systemName: "text.alignleft").foregroundStyle(Color.accentDeep)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentDeep)
                Text(entry.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .steadyCard()
    }
}

// MARK: - Éditeur de note

struct JournalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// `nil` = nouvelle note ; sinon édition d'une note existante.
    let entry: JournalEntry?

    @State private var text: String = ""
    @State private var mood: Int?
    @State private var prompt: String = JournalPrompts.today()
    @State private var analysis: JournalAnalysis?

    private let ai = JournalAIService()
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                promptBanner
                moodRow
                editor
            }
            .padding(Theme.Spacing.md)
            .background(AnimatedBackground(animated: false))
            .navigationTitle(entry == nil ? "Nouvelle note" : "Modifier la note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(trimmed.isEmpty)
                        .bold()
                }
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        if entry != nil {
                            Button(role: .destructive) { delete() } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Supprimer la note")
                        }
                        Button { analysis = ai.analyze(trimmed) } label: {
                            Image(systemName: "sparkles").foregroundStyle(Color.accentDeep)
                        }
                        .disabled(trimmed.count < 8)
                        .accessibilityLabel("Analyser avec le coach")
                    }
                }
            }
            .sheet(item: $analysis) { JournalAnalysisView(analysis: $0) }
            .onAppear {
                text = entry?.text ?? ""
                mood = entry?.mood
            }
        }
    }

    // MARK: - Sous-vues

    private var promptBanner: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { prompt = JournalPrompts.random() }
            HapticManager.lightImpact()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "sparkle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.accentGradient))
                Text(prompt)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .steadyCard(cornerRadius: Theme.Radius.md)
        }
        .buttonStyle(.plain)
    }

    private var moodRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("Humeur").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Spacer()
            ForEach(Mood.allCases) { m in
                let selected = mood == m.rawValue
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        mood = selected ? nil : m.rawValue
                    }
                    HapticManager.lightImpact()
                } label: {
                    Text(m.emoji)
                        .font(.title2)
                        .padding(7)
                        .background(Circle().fill(selected ? Color.brandAccent.opacity(0.25) : .clear))
                        .scaleEffect(selected ? 1.12 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.steadyCard)

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.md)
                .font(.body)

            if text.isEmpty {
                Text("Écris ce qui te vient…")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(Theme.Spacing.md)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func save() {
        if let entry {
            entry.text = trimmed
            entry.mood = mood
            entry.date = Date()
        } else {
            modelContext.insert(JournalEntry(text: trimmed, mood: mood))
        }
        try? modelContext.save()
        HapticManager.lightImpact()
        dismiss()
    }

    private func delete() {
        if let entry {
            modelContext.delete(entry)
            try? modelContext.save()
        }
        dismiss()
    }
}
