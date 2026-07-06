import Foundation

/// Une suggestion d'action concrète proposée par le coach.
struct CoachSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
}

/// Analyse les habitudes pour proposer des actions utiles (changer un rappel,
/// fractionner, supprimer une habitude jamais faite, créer une routine, faire une pause).
@MainActor
struct SmartSuggestionEngine {
    private let cal = Calendar.current

    func suggestions(habits: [Habit], store: HabitStore) -> [CoachSuggestion] {
        var out: [CoachSuggestion] = []
        func add(_ icon: String, _ title: String, _ text: String) {
            out.append(CoachSuggestion(icon: icon, title: title, text: text))
        }
        let today = cal.startOfDay(for: Date())

        for habit in habits {
            let completions = habit.records.filter { $0.count >= habit.dailyGoal }
            let ageDays = cal.dateComponents([.day], from: cal.startOfDay(for: habit.creationDate), to: today).day ?? 0

            // Habitude jamais réalisée depuis longtemps → suggérer de la retirer.
            if completions.isEmpty && ageDays >= 10 {
                add("trash", L("Faire le tri"),
                    L("Tu n'as jamais validé « \(habit.name) » depuis \(ageDays) jours. La retirer allégerait ta liste."))
                continue
            }

            // Objectif élevé souvent manqué → fractionner.
            if habit.dailyGoal >= 5 && habitRate(habit) < 0.4 {
                add("scissors", L("Fractionner"),
                    L("« \(habit.name) » (objectif \(habit.dailyGoal)) est souvent manquée. Réduis l'objectif pour reprendre l'élan."))
            }

            // Heure de rappel sous-optimale.
            if habit.reminderEnabled, let suggested = store.suggestedReminderHour(for: habit) {
                let current = habit.reminderTime.map { cal.component(.hour, from: $0) }
                if current == nil || abs((current ?? suggested) - suggested) >= 2 {
                    add("clock.badge.checkmark", L("Mieux planifier"),
                        L("Tu réussis « \(habit.name) » surtout vers \(suggested)h. Déplace son rappel à cette heure."))
                }
            }
        }

        // Routine du matin / du soir si peu d'habitudes sur ces créneaux.
        let hours = habits.flatMap { h in h.records.compactMap { r -> Int? in
            let c = cal.dateComponents([.hour], from: r.date); return c.hour == 0 ? nil : c.hour } }
        if !hours.isEmpty {
            let mornings = hours.filter { (5..<11).contains($0) }.count
            let evenings = hours.filter { $0 >= 19 }.count
            if mornings == 0 {
                add("sunrise.fill", L("Créer une routine du matin"),
                    L("Une petite routine matinale ancre ta journée. Essaie une routine du matin dans le catalogue."))
            }
            if evenings == 0 {
                add("moon.stars.fill", L("Créer une routine du soir"),
                    L("Un rituel du soir améliore le sommeil et la régularité. Découvre une routine du soir."))
            }
        }

        // Trop d'habitudes très exigeantes → suggérer une pause.
        let longStreaks = habits.filter { store.currentStreak(for: $0) >= 21 }.count
        if longStreaks >= 3 {
            add("pause.circle.fill", L("S'autoriser une pause"),
                L("Tu tiens plusieurs longues séries. Pense à un jour « bienveillance » pour souffler sans culpabiliser."))
        }

        return out
    }

    private func habitRate(_ habit: Habit) -> Double {
        let today = cal.startOfDay(for: Date())
        let completed = Set(habit.records.filter { $0.count >= habit.dailyGoal }.map { cal.startOfDay(for: $0.date) })
        var scheduled = 0, done = 0
        for offset in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            guard day >= cal.startOfDay(for: habit.creationDate), habit.isScheduled(on: day) else { continue }
            scheduled += 1
            if completed.contains(day) { done += 1 }
        }
        return scheduled > 0 ? Double(done) / Double(scheduled) : 1
    }
}
