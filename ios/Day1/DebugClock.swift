import Foundation
import RoutineCore

/// Debug builds only: launch with the environment variable
/// `DAY1_FAKE_NOW=2026-10-05T11:10:00` (local time) to preview the screen at
/// another moment. Release builds always use the real clock.
enum DebugClock {
    static let offset: TimeInterval = {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["DAY1_FAKE_NOW"] {
            let f = DateFormatter()
            f.calendar = Routine.calendar
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = f.date(from: raw) { return date.timeIntervalSinceNow }
        }
        #endif
        return 0
    }()

    static func now(_ date: Date = Date()) -> Date {
        offset == 0 ? date : date.addingTimeInterval(offset)
    }
}
