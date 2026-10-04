import Foundation

/// The routine. Mirrors `src/schedule.ts` in the web app. Edit here to change
/// blocks, times, titles, notes or colours; nothing else needs to change.

public enum Category: String, Codable, CaseIterable, Sendable {
    case deep, train, learn, fuel, light, rest
}

public struct BlockDef: Sendable {
    /// Block number as shown on screen. Never renumbered, even when block 10 is skipped.
    public let number: Int
    /// Local wall-clock start, "HH:MM".
    public let start: String
    /// Local wall-clock end, "HH:MM".
    public let end: String
    public let title: String
    public let category: Category
    public let note: String

    public init(number: Int, start: String, end: String, title: String, category: Category, note: String) {
        self.number = number
        self.start = start
        self.end = end
        self.title = title
        self.category = category
        self.note = note
    }
}

public enum Schedule {
    /// First day of the program (local calendar date). Day 1.
    public static let programStart = DateComponents(year: 2026, month: 10, day: 5)
    /// Number of consecutive days in the program. Last day is Tuesday 12 January 2027.
    public static let programDays = 100

    /// Wake time. Sleep state ends here.
    public static let wake = "05:00"
    /// Lights out. Sleep state starts here.
    public static let lightsOut = "22:00"

    /// Block that only happens on odd program days (day 1, 3, 5, ...).
    public static let everySecondDayBlock = 10
    /// Block that extends to fill the gap on even days.
    public static let extendedBlock = 9
    public static let extendedTitle = "Deep work 3 - Sink as the operator (extended)"

    /// Block during which "Tomorrow's top 3" inputs are shown.
    public static let tomorrowTop3Block = 13
    /// Block during which the learning log input is shown.
    public static let learningLogBlock = 12

    public static let blocks: [BlockDef] = [
        BlockDef(number: 1, start: "05:00", end: "05:30", title: "Wake, no screens", category: .rest,
                 note: "Water, daylight, 10 min mobility. Read tomorrow's top 3 from last night."),
        BlockDef(number: 2, start: "05:30", end: "06:15", title: "Deep work 1 - The ONE thing", category: .deep,
                 note: "Most important Sink / farm task of the day. Offline, phone in another room."),
        BlockDef(number: 3, start: "06:15", end: "07:30", title: "Swim / cardio", category: .train,
                 note: "Swim 6:30 - 7:30. Includes travel and shower. Breakfast on the go."),
        BlockDef(number: 4, start: "07:30", end: "10:00", title: "Deep work 2 - Build the farm plan", category: .deep,
                 note: "Robin and Sarge site plan, business model, design brief, costings."),
        BlockDef(number: 5, start: "10:00", end: "10:30", title: "Admin + travel", category: .light,
                 note: "Clear messages once. Travel to CrossFit."),
        BlockDef(number: 6, start: "10:30", end: "12:30", title: "CrossFit", category: .train,
                 note: "Full effort, includes shower. Lunch on the go straight after."),
        BlockDef(number: 7, start: "12:30", end: "15:15", title: "Calls + partners", category: .light,
                 note: "All meetings batched here: family partners, planners, architects, suppliers."),
        BlockDef(number: 8, start: "15:15", end: "15:30", title: "Walk reset", category: .rest,
                 note: "Outside, no phone. Resets focus for the afternoon."),
        BlockDef(number: 9, start: "15:30", end: "17:15", title: "Deep work 3 - Sink as the operator", category: .deep,
                 note: "Management model, brand, systems and SOPs that let Sink run the farm and padel."),
        BlockDef(number: 10, start: "17:15", end: "18:30", title: "Bike / row", category: .train,
                 note: "Ride 17:30 - 18:30, easy zone 2, includes shower."),
        BlockDef(number: 11, start: "18:30", end: "19:15", title: "Dinner", category: .fuel,
                 note: "Sit-down meal, finished by 19:15 to protect sleep."),
        BlockDef(number: 12, start: "19:15", end: "20:00", title: "Deep skill learning", category: .learn,
                 note: "One skill, one course or book, 45 min. No inbox. Log what you learned in one line."),
        BlockDef(number: 13, start: "20:00", end: "21:00", title: "Light work + shutdown", category: .light,
                 note: "Inbox, progress log, write tomorrow's top 3. Workday ends at 21:00."),
        BlockDef(number: 14, start: "21:00", end: "22:00", title: "Wind down", category: .rest,
                 note: "Screens off, lights low, stretch or read. Lights out 22:00."),
    ]
}

public struct CategoryStyle: Sendable {
    public let label: String
    public let lightFill: String
    public let lightText: String
    public let darkFill: String
    public let darkText: String
}

public extension Category {
    var style: CategoryStyle {
        switch self {
        case .deep:
            return CategoryStyle(label: "Deep work - Sink / farm",
                                 lightFill: "#E6F1FB", lightText: "#185FA5", darkFill: "#0C447C", darkText: "#B5D4F4")
        case .train:
            return CategoryStyle(label: "Training",
                                 lightFill: "#E1F5EE", lightText: "#0F6E56", darkFill: "#0B4A3B", darkText: "#A3E4CF")
        case .learn:
            return CategoryStyle(label: "Skill learning",
                                 lightFill: "#FBEAF0", lightText: "#993556", darkFill: "#5E1F37", darkText: "#F4B9CD")
        case .fuel:
            return CategoryStyle(label: "Dinner",
                                 lightFill: "#FAEEDA", lightText: "#854F0B", darkFill: "#553308", darkText: "#F5D08E")
        case .light:
            return CategoryStyle(label: "Light work",
                                 lightFill: "#F1EFE8", lightText: "#5F5E5A", darkFill: "#3A3936", darkText: "#D6D4CE")
        case .rest:
            return CategoryStyle(label: "Rest / recovery",
                                 lightFill: "#EEEDFE", lightText: "#534AB7", darkFill: "#2C2775", darkText: "#C7C2F6")
        }
    }
}
