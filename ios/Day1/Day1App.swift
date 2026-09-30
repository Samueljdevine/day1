import SwiftUI
import WidgetKit
import RoutineCore

@main
struct Day1App: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = DayModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Everything is derived from the clock on every frame, but the
            // stored data, the widget timeline and the notification queue are
            // refreshed each time the app comes to the foreground.
            model.reload()
            UIApplication.shared.isIdleTimerDisabled = model.keepAwake
            Task { await Notifier.scheduleNext24Hours() }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
