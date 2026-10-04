import Foundation
import Observation
import WidgetKit
import RoutineCore

/// Holds today's stored data (top 3, learning log, done ticks) and the
/// tap-to-preview state. The current block itself is never stored here; views
/// derive it from the clock on every tick.
@MainActor
@Observable
final class DayModel {
    private let store = RoutineStore.shared

    private(set) var dateKey = ""
    private(set) var tomorrowKey = ""
    private(set) var top3Today: [RoutineStore.Top3Item] = []
    private(set) var top3Tomorrow: [RoutineStore.Top3Item] = []
    private(set) var learn = ""
    private(set) var done: Set<Int> = []
    private(set) var streak = 0
    private(set) var preview: Block?

    var keepAwake: Bool {
        didSet { store.keepAwake = keepAwake }
    }

    private var previewTask: Task<Void, Never>?
    private var widgetTask: Task<Void, Never>?

    init() {
        keepAwake = store.keepAwake
        reload()
    }

    func reload(now: Date = DebugClock.now()) {
        dateKey = Routine.dateKey(now)
        tomorrowKey = Routine.dateKey(Routine.addDays(now, 1))
        top3Today = store.top3(for: dateKey)
        top3Tomorrow = store.top3(for: tomorrowKey)
        learn = store.learn(for: dateKey)
        done = Set(Schedule.blocks.map(\.number).filter { store.isDone($0, for: dateKey) })
        refreshStreak(now: now)
    }

    /// Cheap check called on every layout tick. Reloads when the local date rolls over.
    func ensureDate(_ now: Date) {
        if Routine.dateKey(now) != dateKey { reload(now: now) }
    }

    func setTop3Today(_ items: [RoutineStore.Top3Item]) {
        top3Today = items
        store.setTop3(items, for: dateKey)
        scheduleWidgetReload()
    }

    func setTop3Tomorrow(_ items: [RoutineStore.Top3Item]) {
        top3Tomorrow = items
        store.setTop3(items, for: tomorrowKey)
        scheduleWidgetReload()
    }

    func setLearn(_ text: String) {
        learn = text
        store.setLearn(text, for: dateKey)
        refreshStreak()
    }

    func setDone(_ block: Int, _ isDone: Bool) {
        if isDone { done.insert(block) } else { done.remove(block) }
        store.setDone(block, isDone, for: dateKey)
    }

    func resetToday() {
        store.resetDay(dateKey)
        reload()
        scheduleWidgetReload()
    }

    func startPreview(_ block: Block) {
        preview = block
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.preview = nil
        }
    }

    private func refreshStreak(now: Date = DebugClock.now()) {
        streak = Routine.learningStreak(hasEntry: store.hasLearnEntry, today: now)
    }

    /// Reloads from the foreground app do not count against the widget budget,
    /// but there is no point doing it on every keystroke.
    private func scheduleWidgetReload() {
        widgetTask?.cancel()
        widgetTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
