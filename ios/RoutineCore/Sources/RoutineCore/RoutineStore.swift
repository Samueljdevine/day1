import Foundation

/// Persistence in the shared App Group `UserDefaults`, so the widget can read
/// what the app writes. Keys match the web app:
///
///   top3:<YYYY-MM-DD>            JSON [{ text, done } x3]
///   learn:<YYYY-MM-DD>           string
///   done:<YYYY-MM-DD>:<block>    bool
///   setting:<name>
public final class RoutineStore {
    /// Must match the App Group in both targets' entitlements.
    public static let appGroup = "group.com.sinkrundown.day1"

    public static let shared = RoutineStore()

    public struct Top3Item: Codable, Equatable, Sendable {
        public var text: String
        public var done: Bool
        public init(text: String = "", done: Bool = false) {
            self.text = text
            self.done = done
        }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: RoutineStore.appGroup) ?? .standard
    }

    // MARK: Top 3

    public func top3(for dateKey: String) -> [Top3Item] {
        var items = [Top3Item(), Top3Item(), Top3Item()]
        if let data = defaults.data(forKey: "top3:\(dateKey)"),
           let decoded = try? JSONDecoder().decode([Top3Item].self, from: data) {
            for (i, item) in decoded.prefix(3).enumerated() { items[i] = item }
        }
        return items
    }

    public func setTop3(_ items: [Top3Item], for dateKey: String) {
        let trimmed = Array(items.prefix(3))
        if let data = try? JSONEncoder().encode(trimmed) {
            defaults.set(data, forKey: "top3:\(dateKey)")
        }
    }

    // MARK: Learning log

    public func learn(for dateKey: String) -> String {
        defaults.string(forKey: "learn:\(dateKey)") ?? ""
    }

    public func setLearn(_ text: String, for dateKey: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.removeObject(forKey: "learn:\(dateKey)")
        } else {
            defaults.set(text, forKey: "learn:\(dateKey)")
        }
    }

    public func hasLearnEntry(_ dateKey: String) -> Bool {
        !learn(for: dateKey).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Block done

    public func isDone(_ blockNumber: Int, for dateKey: String) -> Bool {
        defaults.bool(forKey: "done:\(dateKey):\(blockNumber)")
    }

    public func setDone(_ blockNumber: Int, _ done: Bool, for dateKey: String) {
        let key = "done:\(dateKey):\(blockNumber)"
        if done { defaults.set(true, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    /// Clears the block checkboxes and the top-3 done ticks for the day. Keeps the text.
    public func resetDay(_ dateKey: String) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("done:\(dateKey):") {
            defaults.removeObject(forKey: key)
        }
        let items = top3(for: dateKey)
        if items.contains(where: { $0.done }) {
            setTop3(items.map { Top3Item(text: $0.text, done: false) }, for: dateKey)
        }
    }

    // MARK: Settings

    public var keepAwake: Bool {
        get { defaults.bool(forKey: "setting:keepAwake") }
        set { defaults.set(newValue, forKey: "setting:keepAwake") }
    }
}
