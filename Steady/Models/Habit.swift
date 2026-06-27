import SwiftData
import Foundation

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var creationDate: Date
    
    @Relationship(deleteRule: .cascade)
    var records: [DailyRecord] = []
    
    init(name: String, icon: String, colorHex: String = "#8DA399") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.creationDate = Date()
    }
}
