import SwiftData
import Foundation

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""
    /// Humeur associée (0 = triste, 1 = neutre, 2 = heureux ; nil = non renseignée).
    var mood: Int?

    init(text: String, date: Date = Date(), mood: Int? = nil) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.mood = mood
    }
}
