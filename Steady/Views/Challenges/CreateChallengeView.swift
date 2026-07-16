import SwiftUI

/// Formulaire de création d'un défi personnalisé.
struct CreateChallengeView: View {
    let habits: [Habit]
    /// Appelé à la validation : (titre, icône, objectif, unité, quotidien ?, durée en jours, habitude liée).
    var onCreate: (String, String, Int, String, Bool, Int, Habit?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var icon = "trophy.fill"
    @State private var isDaily = true
    @State private var dailyTarget = 21          // objectif en jours (défi quotidien)
    @State private var cumulativeTarget = 100    // objectif cumulé (défi libre)
    @State private var unit = ""
    @State private var windowDays = 30           // durée pour un défi cumulé
    @State private var linkedHabit: Habit?

    /// Petit choix d'icônes adaptées aux défis.
    private static let icons = [
        "trophy.fill", "flame.fill", "figure.run", "figure.strengthtraining.traditional",
        "book.fill", "brain.head.profile", "drop.fill", "leaf.fill",
        "sunrise.fill", "moon.stars.fill", "heart.fill", "bolt.fill",
        "snowflake", "iphone.slash", "fork.knife", "music.note"
    ]

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespaces) }
    private var canCreate: Bool {
        !cleanTitle.isEmpty && (isDaily ? dailyTarget > 0 : (cumulativeTarget > 0 && !unit.trimmingCharacters(in: .whitespaces).isEmpty))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Nom
                    field("Nom du défi") {
                        TextField("Ex. 30 jours de sport", text: $title)
                            .padding(Theme.Spacing.md)
                            .steadyCard(cornerRadius: Theme.Radius.md)
                    }

                    // Icône
                    field("Icône") {
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
                        .padding(Theme.Spacing.md)
                        .steadyCard(cornerRadius: Theme.Radius.md)
                    }

                    // Type
                    field("Type de défi") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Picker("", selection: $isDaily) {
                                Text("Quotidien").tag(true)
                                Text("Cumulé").tag(false)
                            }
                            .pickerStyle(.segmented)

                            Text(isDaily
                                 ? "Une validation par jour. Ex. « méditer 21 jours »."
                                 : "Un total à atteindre à ton rythme. Ex. « 100 pompes », « 50 km ».")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Objectif
                    if isDaily {
                        field("Objectif") {
                            Stepper(value: $dailyTarget, in: 3...90) {
                                Text("\(dailyTarget) jours").font(.body.weight(.semibold))
                            }
                            .padding(Theme.Spacing.md)
                            .steadyCard(cornerRadius: Theme.Radius.md)
                        }

                        if !habits.isEmpty {
                            field("Relier à une habitude (optionnel)") {
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    Menu {
                                        Button(L("Aucune")) { linkedHabit = nil }
                                        ForEach(habits) { habit in
                                            Button(habit.name) { linkedHabit = habit }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: linkedHabit?.icon ?? "link")
                                            Text(linkedHabit?.name ?? L("Choisir une habitude"))
                                            Spacer()
                                            Image(systemName: "chevron.up.chevron.down").font(.caption)
                                        }
                                        .padding(Theme.Spacing.md)
                                        .steadyCard(cornerRadius: Theme.Radius.md)
                                    }
                                    Text("Le défi progressera tout seul quand tu valides cette habitude.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        field("Objectif") {
                            VStack(spacing: Theme.Spacing.sm) {
                                HStack {
                                    TextField("100", value: $cumulativeTarget, format: .number)
                                        .keyboardType(.numberPad)
                                        .frame(width: 80)
                                        .multilineTextAlignment(.center)
                                        .padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.secondary.opacity(0.1)))
                                    TextField("pompes, km, pages…", text: $unit)
                                        .padding(.horizontal, 12).padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.secondary.opacity(0.1)))
                                }
                                Stepper(value: $windowDays, in: 7...90, step: 7) {
                                    Text("En \(windowDays) jours").font(.subheadline.weight(.medium))
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .steadyCard(cornerRadius: Theme.Radius.md)
                        }
                    }

                    // Créer
                    Button {
                        let target = isDaily ? dailyTarget : cumulativeTarget
                        let finalUnit = isDaily ? L("jours") : unit.trimmingCharacters(in: .whitespaces)
                        // Quotidien : même marge de temps que les défis du catalogue.
                        let window = isDaily ? dailyTarget + 3 : windowDays   // même grâce que le catalogue
                        onCreate(cleanTitle, icon, target, finalUnit, isDaily, window, isDaily ? linkedHabit : nil)
                        dismiss()
                    } label: {
                        Text("Créer mon défi")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(canCreate ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.secondary.opacity(0.3))))
                    }
                    .disabled(!canCreate)
                    .padding(.top, Theme.Spacing.sm)
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(AnimatedBackground())
            .navigationTitle("Nouveau défi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private func field<Content: View>(_ label: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label).font(.subheadline.weight(.semibold))
            content()
        }
    }
}
