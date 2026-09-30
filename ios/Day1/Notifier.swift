import Foundation
import UserNotifications
import RoutineCore

/// Local notifications at each block start, scheduled 24 hours ahead every
/// time the app opens. iOS delivers these itself, so the app does not need to
/// be running.
enum Notifier {
    private static let prefix = "block-"

    static func scheduleNext24Hours(now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()

        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let calendar = Routine.calendar
        for block in Routine.upcomingBlocks(from: now, hours: 24, calendar: calendar) {
            let content = UNMutableNotificationContent()
            content.title = String(format: "Block %02d · %@", block.number, block.title)
            content.body = "until \(block.endLabel)"
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            // A time-interval trigger avoids any dependence on the device's
            // default calendar (a Thai region uses the Buddhist year).
            let delay = block.start.timeIntervalSince(now)
            guard delay > 0 else { continue }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let id = "\(prefix)\(Routine.dateKey(block.start, calendar: calendar))-\(block.number)"
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
