import SwiftData
import Foundation

/// Un examen/partiel suivi par l'étudiant (persisté, synchronisé iCloud).
/// Cœur du « Exam Mode » : compte à rebours, focus révision, allègement pendant le rush.
@Model
final class Exam {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var icon: String = "graduationcap.fill"
    var createdDate: Date = Date()
    /// Habitude « réviser » liée (optionnel) — le focus la fait progresser.
    var focusHabitID: UUID?

    init(title: String, date: Date, icon: String = "graduationcap.fill", focusHabitID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.icon = icon
        self.createdDate = Date()
        self.focusHabitID = focusHabitID
    }

    /// Jours restants avant l'examen (0 = aujourd'hui, négatif = passé).
    var daysRemaining: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
    }

    var isPast: Bool { daysRemaining < 0 }

    /// Couleur d'urgence selon la proximité.
    var urgency: ExamUrgency {
        switch daysRemaining {
        case ..<0: return .past
        case 0...2: return .critical
        case 3...7: return .soon
        default: return .calm
        }
    }
}

enum ExamUrgency {
    case past, critical, soon, calm
}
