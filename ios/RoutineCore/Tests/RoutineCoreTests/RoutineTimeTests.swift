import XCTest
@testable import RoutineCore

/// Mirrors test/time.test.ts from the web app.
final class RoutineTimeTests: XCTestCase {
    // MARK: Helpers

    private func cal(_ tz: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        c.locale = Locale(identifier: "en_IE")
        return c
    }

    private func local(_ c: Calendar, _ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        c.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    private func numbers(_ c: Calendar, _ date: Date) -> [Int] {
        Routine.blocks(for: date, calendar: c).map(\.number)
    }

    private let dublin = { () -> Calendar in
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Dublin")!
        return c
    }()

    // MARK: Europe/Dublin, clocks back 25 October 2026

    func testDublinClockChangeDayIs25Hours() {
        let c = cal("Europe/Dublin")
        let hours = local(c, 2026, 10, 26).timeIntervalSince(local(c, 2026, 10, 25)) / 3600
        XCTAssertEqual(hours, 25)
    }

    func testDublinDayNumbersAcrossClockChange() {
        let c = cal("Europe/Dublin")
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 5), calendar: c), 1)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 24, 23, 59, 59), calendar: c), 20)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 25, 0, 30), calendar: c), 21)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 25, 12), calendar: c), 21)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 25, 23, 59, 59), calendar: c), 21)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 26, 0, 0, 0), calendar: c), 22)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 26, 12), calendar: c), 22)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 12, 31), calendar: c), 88)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2027, 1, 12, 23, 59, 59), calendar: c), 100)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 4), calendar: c), 0)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2027, 1, 13), calendar: c), 101)
    }

    func testDublinOddEvenRuleAroundClockChange() {
        let c = cal("Europe/Dublin")
        XCTAssertTrue(numbers(c, local(c, 2026, 10, 25, 12)).contains(10)) // day 21, odd
        XCTAssertFalse(numbers(c, local(c, 2026, 10, 26, 12)).contains(10)) // day 22, even
        XCTAssertTrue(numbers(c, local(c, 2026, 10, 27, 12)).contains(10)) // day 23, odd
    }

    func testDublinBlocksOnClockChangeDayUseWallClock() {
        let c = cal("Europe/Dublin")
        let blocks = Routine.blocks(for: local(c, 2026, 10, 25, 12), calendar: c)
        XCTAssertEqual(c.component(.hour, from: blocks[0].start), 5)
        XCTAssertEqual(c.component(.minute, from: blocks[0].start), 0)
        XCTAssertEqual(c.component(.hour, from: blocks.last!.end), 22)
        let crossfit = blocks.first { $0.number == 6 }!
        XCTAssertEqual(c.component(.hour, from: crossfit.start), 10)
        XCTAssertEqual(c.component(.minute, from: crossfit.start), 30)
    }

    // MARK: America/Toronto, clocks back 1 November 2026

    func testTorontoClockChangeDayIs25Hours() {
        let c = cal("America/Toronto")
        let hours = local(c, 2026, 11, 2).timeIntervalSince(local(c, 2026, 11, 1)) / 3600
        XCTAssertEqual(hours, 25)
    }

    func testTorontoDayNumbersAcrossClockChange() {
        let c = cal("America/Toronto")
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 31, 23, 59, 59), calendar: c), 27)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 11, 1, 0, 0, 0), calendar: c), 28)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 11, 1, 1, 30), calendar: c), 28)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 11, 1, 23, 59, 59), calendar: c), 28)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 11, 2, 0, 0, 0), calendar: c), 29)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 11, 2, 12), calendar: c), 29)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 12, 31, 23, 59, 59), calendar: c), 88)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2027, 1, 12, 12), calendar: c), 100)
    }

    func testTorontoOddEvenRuleAroundClockChange() {
        let c = cal("America/Toronto")
        XCTAssertTrue(numbers(c, local(c, 2026, 10, 31, 12)).contains(10)) // day 27
        XCTAssertFalse(numbers(c, local(c, 2026, 11, 1, 12)).contains(10)) // day 28
        XCTAssertTrue(numbers(c, local(c, 2026, 11, 2, 12)).contains(10)) // day 29
    }

    // MARK: Asia/Bangkok, no clock change

    func testBangkokHasNoClockChange() {
        let c = cal("Asia/Bangkok")
        let hours = local(c, 2026, 10, 26).timeIntervalSince(local(c, 2026, 10, 25)) / 3600
        XCTAssertEqual(hours, 24)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 10, 25), calendar: c), 21)
        XCTAssertEqual(Routine.dayNumber(for: local(c, 2026, 11, 1), calendar: c), 28)
    }

    // MARK: Default calendar

    func testDefaultCalendarIsGregorianInDeviceTimeZone() {
        XCTAssertEqual(Routine.calendar.identifier, .gregorian)
        XCTAssertEqual(Routine.calendar.timeZone.identifier, TimeZone.current.identifier)
    }

    func testBuddhistDeviceCalendarDoesNotAffectDayNumbers() {
        // Simulates a phone set to a Thai region: Calendar.current would be Buddhist.
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let gregorian = cal("Asia/Bangkok")
        let oct1 = local(gregorian, 2026, 10, 5, 9, 0)
        // Using the library's own default calendar (Gregorian) gives day 1 regardless of the device calendar.
        var pinned = Routine.calendar
        pinned.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        XCTAssertEqual(Routine.dayNumber(for: oct1, calendar: pinned), 1)
        XCTAssertEqual(buddhist.component(.year, from: oct1), 2569)
    }

    // MARK: Program window

    func testProgramStatus() {
        let c = dublin
        XCTAssertEqual(Routine.programStatus(for: local(c, 2026, 10, 4, 23, 59, 59), calendar: c), .before)
        XCTAssertEqual(Routine.programStatus(for: local(c, 2026, 10, 5), calendar: c), .active)
        XCTAssertEqual(Routine.programStatus(for: local(c, 2027, 1, 12, 23, 59, 59), calendar: c), .active)
        XCTAssertEqual(Routine.programStatus(for: local(c, 2027, 1, 13), calendar: c), .after)
    }

    func testHeaderFormatting() {
        let c = dublin
        XCTAssertEqual(Routine.headerDate(local(c, 2026, 10, 5), calendar: c), "Mon 5 Oct")
        XCTAssertEqual(Routine.headerDate(local(c, 2027, 1, 12), calendar: c), "Tue 12 Jan")
        XCTAssertEqual(Routine.programDay(local(c, 2026, 10, 5), calendar: c), "Day 1 of 100")
        XCTAssertEqual(Routine.programDay(local(c, 2027, 1, 12), calendar: c), "Day 100 of 100")
        XCTAssertEqual(Routine.programDay(local(c, 2026, 10, 4), calendar: c), "Program starts 5 Oct")
        XCTAssertEqual(Routine.programDay(local(c, 2027, 1, 13), calendar: c), "Program complete")
    }

    func testRoutineStillBuildsOutsideProgramWindow() {
        let c = dublin
        XCTAssertFalse(Routine.blocks(for: local(c, 2026, 10, 4), calendar: c).isEmpty)
        XCTAssertFalse(Routine.blocks(for: local(c, 2027, 1, 13), calendar: c).isEmpty)
    }

    // MARK: Odd and even days

    func testOddDayHasAllFourteenBlocks() {
        let c = dublin
        XCTAssertEqual(numbers(c, local(c, 2026, 10, 5)), Array(1...14))
        let b9 = Routine.blocks(for: local(c, 2026, 10, 5), calendar: c).first { $0.number == 9 }!
        XCTAssertEqual(b9.title, "Deep work 3 - Sink as the operator")
        XCTAssertEqual(b9.endLabel, "17:15")
    }

    func testEvenDayDropsBlockTenAndExtendsBlockNine() {
        let c = dublin
        let blocks = Routine.blocks(for: local(c, 2026, 10, 6), calendar: c)
        XCTAssertEqual(blocks.map(\.number), [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14])
        let b9 = blocks.first { $0.number == 9 }!
        XCTAssertEqual(b9.title, Schedule.extendedTitle)
        XCTAssertEqual(b9.startLabel, "15:30")
        XCTAssertEqual(b9.endLabel, "18:30")
        XCTAssertEqual(c.component(.hour, from: b9.end), 18)
        XCTAssertEqual(c.component(.minute, from: b9.end), 30)
        XCTAssertEqual(blocks.first { $0.number == 11 }!.startLabel, "18:30")
    }

    func testCountsByProgramDayNotCalendarDate() {
        let c = dublin
        XCTAssertTrue(numbers(c, local(c, 2026, 10, 5)).contains(10)) // day 1
        XCTAssertFalse(numbers(c, local(c, 2026, 10, 6)).contains(10)) // day 2
        XCTAssertFalse(numbers(c, local(c, 2026, 11, 1)).contains(10)) // day 28
        XCTAssertTrue(numbers(c, local(c, 2026, 11, 2)).contains(10)) // day 29
        XCTAssertFalse(numbers(c, local(c, 2027, 1, 12)).contains(10)) // day 100
    }

    func testCurrentBlockAtSixPmOnEvenAndOddDays() {
        let c = dublin
        let even = local(c, 2026, 10, 6, 18, 0, 0)
        let cur = Routine.currentBlock(in: Routine.blocks(for: even, calendar: c), at: even, calendar: c)
        XCTAssertEqual(cur.number, 9)
        XCTAssertEqual(cur.title, Schedule.extendedTitle)

        let odd = local(c, 2026, 10, 7, 18, 0, 0)
        XCTAssertEqual(Routine.currentBlock(in: Routine.blocks(for: odd, calendar: c), at: odd, calendar: c).number, 10)
    }

    // MARK: Sleep state

    private func at(_ h: Int, _ m: Int, _ s: Int, day: Int = 10) -> Block {
        let c = dublin
        let now = local(c, 2026, 10, day, h, m, s)
        return Routine.currentBlock(in: Routine.blocks(for: now, calendar: c), at: now, calendar: c)
    }

    func testSleepFrom2200() {
        let c = dublin
        let b = at(22, 0, 0)
        XCTAssertTrue(b.isSleep)
        XCTAssertEqual(b.title, "Sleep")
        XCTAssertEqual(b.number, 0)
        XCTAssertEqual(b.end, local(c, 2026, 10, 11, 5, 0, 0))
    }

    func testSleepAt235959CountsDownToTomorrow() {
        let c = dublin
        let b = at(23, 59, 59)
        XCTAssertTrue(b.isSleep)
        XCTAssertEqual(b.endLabel, "05:00")
        XCTAssertEqual(b.end, local(c, 2026, 10, 11, 5, 0, 0))
    }

    func testSleepAtMidnightCountsDownToToday() {
        let c = dublin
        let b = at(0, 0, 0, day: 11)
        XCTAssertTrue(b.isSleep)
        XCTAssertEqual(b.end, local(c, 2026, 10, 11, 5, 0, 0))
        XCTAssertEqual(b.start, local(c, 2026, 10, 10, 22, 0, 0))
    }

    func testSleepEndsAtWake() {
        XCTAssertTrue(at(4, 59, 59).isSleep)
        let wake = at(5, 0, 0)
        XCTAssertFalse(wake.isSleep)
        XCTAssertEqual(wake.number, 1)
    }

    func testBlockFourteenAt215959() {
        let b = at(21, 59, 59)
        XCTAssertEqual(b.number, 14)
        XCTAssertFalse(b.isSleep)
    }

    func testDisplayTitle() {
        XCTAssertEqual(at(23, 0, 0).displayTitle, "Sleep")
        XCTAssertEqual(at(11, 0, 0).displayTitle, "06 · CrossFit")
    }

    // MARK: Exact boundaries

    private func numberAt(_ h: Int, _ m: Int, _ s: Int) -> Int {
        let c = dublin
        let now = local(c, 2026, 10, 1, h, m, s)
        return Routine.currentBlock(in: Routine.blocks(for: now, calendar: c), at: now, calendar: c).number
    }

    func testBoundary1030() {
        XCTAssertEqual(numberAt(10, 29, 59), 5)
        XCTAssertEqual(numberAt(10, 30, 0), 6)
    }

    func testBoundary1915() {
        XCTAssertEqual(numberAt(19, 14, 59), 11)
        XCTAssertEqual(numberAt(19, 15, 0), 12)
    }

    func testBoundary2000() {
        XCTAssertEqual(numberAt(19, 59, 59), 12)
        XCTAssertEqual(numberAt(20, 0, 0), 13)
    }

    func testBlockWithSubSecondLeftIsStillThatBlock() {
        let c = dublin
        let now = local(c, 2026, 10, 1, 10, 29, 59).addingTimeInterval(0.999)
        XCTAssertEqual(Routine.currentBlock(in: Routine.blocks(for: now, calendar: c), at: now, calendar: c).number, 5)
    }

    // MARK: Next block

    private func nextAt(_ h: Int, _ m: Int, day: Int = 1) -> Block {
        let c = dublin
        let now = local(c, 2026, 10, day, h, m, 0)
        return Routine.nextBlock(in: Routine.blocks(for: now, calendar: c), at: now, calendar: c)
    }

    func testNextDuringTheDay() {
        let n = nextAt(12, 0)
        XCTAssertEqual(n.number, 7)
        XCTAssertEqual(n.startLabel, "12:30")
        XCTAssertEqual(n.title, "Calls + partners")
    }

    func testNextIsSleepDuringWindDown() {
        let n = nextAt(21, 30)
        XCTAssertTrue(n.isSleep)
        XCTAssertEqual(n.startLabel, "22:00")
    }

    func testNextIsTomorrowBlockOneAfterLightsOut() {
        let c = dublin
        let n = nextAt(23, 0)
        XCTAssertEqual(n.number, 1)
        XCTAssertEqual(n.start, local(c, 2026, 10, 2, 5, 0, 0))
    }

    func testNextIsTodayBlockOneBeforeWake() {
        let c = dublin
        let n = nextAt(3, 0, day: 2)
        XCTAssertEqual(n.number, 1)
        XCTAssertEqual(n.start, local(c, 2026, 10, 2, 5, 0, 0))
    }

    // MARK: formatRemaining

    func testFormatRemainingOverAnHour() {
        XCTAssertEqual(Routine.formatRemaining(3600), "1:00:00")
        XCTAssertEqual(Routine.formatRemaining(5025), "1:23:45")
        XCTAssertEqual(Routine.formatRemaining(2 * 3600 + 45 * 60), "2:45:00")
    }

    func testFormatRemainingUnderAnHour() {
        XCTAssertEqual(Routine.formatRemaining(3599), "59:59")
        XCTAssertEqual(Routine.formatRemaining(1425), "23:45")
    }

    func testFormatRemainingUnderAMinute() {
        XCTAssertEqual(Routine.formatRemaining(45), "00:45")
        XCTAssertEqual(Routine.formatRemaining(1), "00:01")
    }

    func testFormatRemainingRoundsUpAndClamps() {
        XCTAssertEqual(Routine.formatRemaining(0.5), "00:01")
        XCTAssertEqual(Routine.formatRemaining(0), "00:00")
        XCTAssertEqual(Routine.formatRemaining(-5), "00:00")
    }

    // MARK: Learning streak

    private func streak(_ daysAgo: [Int]) -> Int {
        let c = dublin
        let today = local(c, 2026, 10, 20, 19, 30)
        let keys = Set(daysAgo.map { Routine.dateKey(local(c, 2026, 10, 20 - $0), calendar: c) })
        return Routine.learningStreak(hasEntry: { keys.contains($0) }, today: today, calendar: c)
    }

    func testStreakZeroWithNoEntries() {
        XCTAssertEqual(streak([]), 0)
    }

    func testStreakEndingToday() {
        XCTAssertEqual(streak([0]), 1)
        XCTAssertEqual(streak([0, 1, 2]), 3)
    }

    func testStreakEndingYesterday() {
        XCTAssertEqual(streak([1, 2]), 2)
        XCTAssertEqual(streak([1, 2, 3, 4]), 4)
    }

    func testStreakBrokenTwoDaysAgo() {
        XCTAssertEqual(streak([2, 3]), 0)
    }

    func testStreakStopsAtFirstGap() {
        XCTAssertEqual(streak([0, 2, 3]), 1)
        XCTAssertEqual(streak([0, 1, 3]), 2)
    }

    func testStreakAcrossClockChange() {
        let c = dublin
        let keys: Set<String> = [
            Routine.dateKey(local(c, 2026, 10, 26), calendar: c),
            Routine.dateKey(local(c, 2026, 10, 25), calendar: c),
            Routine.dateKey(local(c, 2026, 10, 24), calendar: c),
        ]
        XCTAssertEqual(Routine.learningStreak(hasEntry: { keys.contains($0) }, today: local(c, 2026, 10, 26, 12), calendar: c), 3)
    }

    // MARK: Widget timeline boundaries

    func testBoundariesCoverEveryBlockChangeInNext24Hours() {
        let c = dublin
        let now = local(c, 2026, 10, 1, 10, 0, 30)
        let bounds = Routine.boundaries(from: now, hours: 24, calendar: c)
        XCTAssertEqual(bounds.first, local(c, 2026, 10, 1, 10, 30, 0))
        XCTAssertTrue(bounds.contains(local(c, 2026, 10, 1, 22, 0, 0))) // into Sleep
        XCTAssertTrue(bounds.contains(local(c, 2026, 10, 2, 5, 0, 0))) // wake tomorrow
        XCTAssertTrue(bounds.contains(local(c, 2026, 10, 2, 10, 0, 0)))
        XCTAssertFalse(bounds.contains(local(c, 2026, 10, 2, 10, 30, 0))) // 24h30 away, outside window
        XCTAssertEqual(bounds, bounds.sorted())
        XCTAssertEqual(Set(bounds).count, bounds.count)
        // Each boundary flips to a different block than the instant before it.
        for b in bounds {
            let before = Routine.currentBlock(in: Routine.blocks(for: b.addingTimeInterval(-1), calendar: c), at: b.addingTimeInterval(-1), calendar: c)
            let after = Routine.currentBlock(in: Routine.blocks(for: b, calendar: c), at: b, calendar: c)
            XCTAssertNotEqual(before.id, after.id, "no change at \(b)")
        }
    }

    func testUpcomingBlocksForNotifications() {
        let c = dublin
        let now = local(c, 2026, 10, 5, 20, 30, 0)
        let upcoming = Routine.upcomingBlocks(from: now, hours: 24, calendar: c)
        XCTAssertEqual(upcoming.first?.number, 14)
        XCTAssertEqual(upcoming.first?.start, local(c, 2026, 10, 5, 21, 0, 0))
        // Block 14 tonight, then tomorrow (day 2, even, no block 10) blocks 1-9 and 11-13
        // start by 20:00. Tomorrow's block 14 at 21:00 is outside the 24 h window.
        XCTAssertEqual(upcoming.count, 13)
        XCTAssertEqual(upcoming.last?.number, 13)
        XCTAssertFalse(upcoming.contains { $0.number == 10 && Routine.dayNumber(for: $0.start, calendar: c) == 2 })
    }
}
