import SwiftData
import Foundation

@Model
final class DailyRecord {
    var date: Date
    var status: RecordStatus
    var habit: Habit?
    
    init(date: Date, status: RecordStatus, habit: Habit? = nil) {
        self.date = date
        self.status = status
        self.habit = habit
    }
}
