import Foundation

/// Pure time logic. Mirrors `src/time.ts` in the web app.
/// Every function takes a `Calendar` (defaults to the device's current one) so
/// tests can pin a time zone. All arithmetic is done on local calendar days.

public struct Block: Identifiable, Equatable, Hashable, Sendable {
    /// Block number from the schedule table. 0 for the Sleep state.
    public let number: Int
    public let title: String
    public let category: Category
    public let note: String
    /// Local start instant.
    public let start: Date
    /// Local end instant (exclusive).
    public let end: Date
    /// "HH:MM"
    public let startLabel: String
    /// "HH:MM"
    public let endLabel: String
    public let isSleep: Bool

    public var id: String { "\(number)@\(start.timeIntervalSinceReferenceDate)" }

    /// "06 · CrossFit", or "Sleep".
    public var displayTitle: String {
        isSleep ? title : String(format: "%02d · %@", number, title)
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(now))
    }

    /// Elapsed fraction 0...1 at `now`.
    public func progress(at now: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / duration))
    }
}

public enum ProgramStatus: Sendable {
    case before, active, after
}

public enum Routine {
    /// Always Gregorian, in the device's current time zone. A phone set to a
    /// Thai region defaults to the Buddhist calendar (year 2569), which would
    /// misread the program dates. The time zone still follows the device, so
    /// the routine follows local wall-clock time wherever you are.
    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.autoupdatingCurrent
        return c
    }

    private static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    // MARK: Calendar helpers

    public static func parseHM(_ hm: String) -> (hour: Int, minute: Int) {
        let parts = hm.split(separator: ":").compactMap { Int($0) }
        return (parts.count > 0 ? parts[0] : 0, parts.count > 1 ? parts[1] : 0)
    }

    /// Local midnight of the given date.
    public static func startOfDay(_ date: Date, calendar: Calendar = Routine.calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Local midnight, `n` calendar days away. Safe across clock changes.
    public static func addDays(_ date: Date, _ n: Int, calendar: Calendar = Routine.calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.day = (comps.day ?? 1) + n
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// The instant "HH:MM" on the same local calendar date as `date`.
    public static func atTime(_ date: Date, _ hm: String, calendar: Calendar = Routine.calendar) -> Date {
        let (h, m) = parseHM(hm)
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = h
        comps.minute = m
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }

    /// "YYYY-MM-DD" using the local calendar date. Used for storage keys.
    public static func dateKey(_ date: Date, calendar: Calendar = Routine.calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "HH:MM" local.
    public static func formatHM(_ date: Date, calendar: Calendar = Routine.calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Whole calendar days from `a` to `b`, comparing local year/month/day only.
    /// The local components are re-expressed as UTC midnights (which never have
    /// DST) so 23- and 25-hour days count as exactly one day. Same approach as
    /// the web app's `daysBetween`.
    public static func daysBetween(_ a: Date, _ b: Date, calendar: Calendar = Routine.calendar) -> Int {
        let ca = calendar.dateComponents([.year, .month, .day], from: a)
        let cb = calendar.dateComponents([.year, .month, .day], from: b)
        guard let ua = utcCalendar.date(from: DateComponents(year: ca.year, month: ca.month, day: ca.day)),
              let ub = utcCalendar.date(from: DateComponents(year: cb.year, month: cb.month, day: cb.day)) else {
            return 0
        }
        return Int((ub.timeIntervalSince(ua) / 86_400).rounded())
    }

    private static func programStartDate(calendar: Calendar) -> Date {
        calendar.date(from: Schedule.programStart) ?? Date.distantPast
    }

    // MARK: Program

    /// 1 on the first program day. 0 the day before, 93 the day after the last day.
    public static func dayNumber(for date: Date, calendar: Calendar = Routine.calendar) -> Int {
        daysBetween(programStartDate(calendar: calendar), date, calendar: calendar) + 1
    }

    public static func programStatus(for date: Date, calendar: Calendar = Routine.calendar) -> ProgramStatus {
        let n = dayNumber(for: date, calendar: calendar)
        if n < 1 { return .before }
        if n > Schedule.programDays { return .after }
        return .active
    }

    /// Block 10 (bike / row) is active on odd program days: 1, 3, 5, ...
    public static func isEverySecondDayBlockActive(on date: Date, calendar: Calendar = Routine.calendar) -> Bool {
        dayNumber(for: date, calendar: calendar) % 2 != 0
    }

    // MARK: Blocks

    /// All blocks for the local calendar date of `date`, in order, with real start/end instants.
    public static func blocks(for date: Date, calendar: Calendar = Routine.calendar) -> [Block] {
        let includeAlternate = isEverySecondDayBlockActive(on: date, calendar: calendar)
        let alternateDef = Schedule.blocks.first { $0.number == Schedule.everySecondDayBlock }
        var result: [Block] = []

        for def in Schedule.blocks {
            if def.number == Schedule.everySecondDayBlock && !includeAlternate { continue }

            var title = def.title
            var end = def.end
            if def.number == Schedule.extendedBlock && !includeAlternate, let alt = alternateDef {
                title = Schedule.extendedTitle
                end = alt.end
            }

            result.append(Block(
                number: def.number,
                title: title,
                category: def.category,
                note: def.note,
                start: atTime(date, def.start, calendar: calendar),
                end: atTime(date, end, calendar: calendar),
                startLabel: def.start,
                endLabel: end,
                isSleep: false
            ))
        }
        return result
    }

    /// The Sleep pseudo-block that contains (or follows) `now`.
    public static func sleepBlock(at now: Date, calendar: Calendar = Routine.calendar) -> Block {
        let wakeToday = atTime(now, Schedule.wake, calendar: calendar)
        let start: Date
        let end: Date
        if now < wakeToday {
            start = atTime(addDays(now, -1, calendar: calendar), Schedule.lightsOut, calendar: calendar)
            end = wakeToday
        } else {
            start = atTime(now, Schedule.lightsOut, calendar: calendar)
            end = atTime(addDays(now, 1, calendar: calendar), Schedule.wake, calendar: calendar)
        }
        return Block(
            number: 0,
            title: "Sleep",
            category: .rest,
            note: "Lights out \(Schedule.lightsOut). Wake \(Schedule.wake).",
            start: start,
            end: end,
            startLabel: Schedule.lightsOut,
            endLabel: Schedule.wake,
            isSleep: true
        )
    }

    /// The block containing `now` (start <= now < end), or the Sleep block when
    /// `now` is outside every block for the day.
    public static func currentBlock(in blocks: [Block], at now: Date, calendar: Calendar = Routine.calendar) -> Block {
        blocks.first { $0.start <= now && now < $0.end } ?? sleepBlock(at: now, calendar: calendar)
    }

    /// The next block that starts after `now`. After the last block it is Sleep;
    /// after lights out it is the first block of the following day.
    public static func nextBlock(in blocks: [Block], at now: Date, calendar: Calendar = Routine.calendar) -> Block {
        if let found = blocks.first(where: { $0.start > now }) { return found }
        if let last = blocks.last, now < last.end { return sleepBlock(at: now, calendar: calendar) }
        let tomorrow = self.blocks(for: addDays(now, 1, calendar: calendar), calendar: calendar)
        return tomorrow.first ?? sleepBlock(at: now, calendar: calendar)
    }

    /// Convenience: the current block right now, for the device date.
    public static func current(at now: Date = Date(), calendar: Calendar = Routine.calendar) -> (current: Block, next: Block) {
        let todays = blocks(for: now, calendar: calendar)
        return (currentBlock(in: todays, at: now, calendar: calendar), nextBlock(in: todays, at: now, calendar: calendar))
    }

    /// Every instant in (now, now + hours] at which the current block changes:
    /// each block start and end. Sorted, unique. Used for the widget timeline.
    public static func boundaries(from now: Date, hours: Int = 24, calendar: Calendar = Routine.calendar) -> [Date] {
        let limit = now.addingTimeInterval(TimeInterval(hours) * 3600)
        var set = Set<Date>()
        for offset in 0...2 {
            for block in blocks(for: addDays(now, offset, calendar: calendar), calendar: calendar) {
                for instant in [block.start, block.end] where instant > now && instant <= limit {
                    set.insert(instant)
                }
            }
        }
        return set.sorted()
    }

    /// Blocks whose start falls in (now, now + hours]. Used to schedule notifications.
    public static func upcomingBlocks(from now: Date, hours: Int = 24, calendar: Calendar = Routine.calendar) -> [Block] {
        let limit = now.addingTimeInterval(TimeInterval(hours) * 3600)
        var result: [Block] = []
        for offset in 0...2 {
            for block in blocks(for: addDays(now, offset, calendar: calendar), calendar: calendar)
            where block.start > now && block.start <= limit {
                result.append(block)
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    // MARK: Formatting

    /// "1:23:45" at or over one hour, "23:45" under. Rounds up to the next whole second.
    public static func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// "Thu 1 Oct"
    public static func headerDate(_ date: Date, calendar: Calendar = Routine.calendar) -> String {
        let c = calendar.dateComponents([.weekday, .day, .month], from: date)
        let wd = dayNames[((c.weekday ?? 1) - 1 + 7) % 7]
        let mo = monthNames[((c.month ?? 1) - 1 + 12) % 12]
        return "\(wd) \(c.day ?? 0) \(mo)"
    }

    /// "Day 12 of 92", "Program starts 1 Oct" or "Program complete".
    public static func programDay(_ date: Date, calendar: Calendar = Routine.calendar) -> String {
        switch programStatus(for: date, calendar: calendar) {
        case .before:
            let mo = monthNames[((Schedule.programStart.month ?? 1) - 1 + 12) % 12]
            return "Program starts \(Schedule.programStart.day ?? 1) \(mo)"
        case .after:
            return "Program complete"
        case .active:
            return "Day \(dayNumber(for: date, calendar: calendar)) of \(Schedule.programDays)"
        }
    }

    // MARK: Learning streak

    /// Consecutive calendar days with a learning entry, ending today or yesterday.
    /// `hasEntry` is called with "YYYY-MM-DD" keys.
    public static func learningStreak(hasEntry: (String) -> Bool, today: Date, calendar: Calendar = Routine.calendar) -> Int {
        var day = startOfDay(today, calendar: calendar)
        if !hasEntry(dateKey(day, calendar: calendar)) {
            day = addDays(day, -1, calendar: calendar)
            if !hasEntry(dateKey(day, calendar: calendar)) { return 0 }
        }
        var streak = 0
        while hasEntry(dateKey(day, calendar: calendar)) && streak < 10_000 {
            streak += 1
            day = addDays(day, -1, calendar: calendar)
        }
        return streak
    }
}
