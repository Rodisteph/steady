import SwiftData
import Foundation

/// Humeur du jour (suivi simple : 😔 / 😐 / 😊).
@Model
final class MoodEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    /// 0 = triste, 1 = neutre, 2 = heureux.
    var value: Int = 1

    init(date: Date = Date(), value: Int = 1) {
        self.id = UUID()
        self.date = date
        self.value = value
    }
}

enum Mood: Int, CaseIterable, Identifiable {
    case sad = 0, neutral = 1, happy = 2
    var id: Int { rawValue }
    var emoji: String {
        switch self {
        case .sad: return "😔"
        case .neutral: return "😐"
        case .happy: return "😊"
        }
    }
}
