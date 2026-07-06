import SwiftData
import Foundation

@Model
final class DailyRecord {
    var date: Date = Date()
    var status: RecordStatus = RecordStatus.completed
    /// Avancement du jour pour les habitudes chiffrées (1 = simple validation).
    var count: Int = 1
    var habit: Habit?

    init(date: Date, status: RecordStatus, count: Int = 1, habit: Habit? = nil) {
        self.date = date
        self.status = status
        self.count = count
        self.habit = habit
    }
}
