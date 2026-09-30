import XCTest
@testable import RoutineCore

final class RoutineStoreTests: XCTestCase {
    private var suite: String!
    private var store: RoutineStore!

    override func setUp() {
        super.setUp()
        suite = "RoutineStoreTests.\(UUID().uuidString)"
        store = RoutineStore(defaults: UserDefaults(suiteName: suite)!)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testTop3RoundTrip() {
        XCTAssertEqual(store.top3(for: "2026-10-01").map(\.text), ["", "", ""])
        store.setTop3([.init(text: "Site plan", done: true), .init(text: "Costings"), .init()], for: "2026-10-01")
        let items = store.top3(for: "2026-10-01")
        XCTAssertEqual(items[0].text, "Site plan")
        XCTAssertTrue(items[0].done)
        XCTAssertEqual(items[1].text, "Costings")
        XCTAssertFalse(items[2].done)
    }

    func testLearnAndStreak() {
        store.setLearn("Swift timelines", for: "2026-10-02")
        XCTAssertTrue(store.hasLearnEntry("2026-10-02"))
        store.setLearn("   ", for: "2026-10-02")
        XCTAssertFalse(store.hasLearnEntry("2026-10-02"))
    }

    func testDoneAndReset() {
        store.setDone(6, true, for: "2026-10-01")
        store.setTop3([.init(text: "A", done: true), .init(), .init()], for: "2026-10-01")
        XCTAssertTrue(store.isDone(6, for: "2026-10-01"))
        store.resetDay("2026-10-01")
        XCTAssertFalse(store.isDone(6, for: "2026-10-01"))
        let items = store.top3(for: "2026-10-01")
        XCTAssertEqual(items[0].text, "A")
        XCTAssertFalse(items[0].done)
    }
}
