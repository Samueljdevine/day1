# Day 1 for iOS

A native SwiftUI app plus WidgetKit widgets so the current block, the countdown and what comes next are visible on the home screen and lock screen without opening anything. iOS 17 or later. No third-party packages.

```
ios/
  Day1.xcodeproj            Open this in Xcode
  Day1/                     App target (SwiftUI)
  Day1Widget/               Widget extension (home screen + lock screen)
  RoutineCore/              Local Swift package: schedule, time logic, storage, tests
```

`RoutineCore` is a line-for-line port of `src/schedule.ts`, `src/time.ts` and `src/storage.ts` from the web app, with the same XCTest cases as the Vitest suite (day numbers across the Dublin and Toronto clock changes, odd/even days, sleep state, exact boundaries, countdown formatting, learning streak) plus widget-timeline and notification-window tests.

## What is in the app

- **Main screen** mirrors the web app: header, Now card with live countdown, "Next" line, top 3 for today (and tomorrow's during block 13), learning log during block 12 with the streak line, the full day list with done ticks and tap-to-preview, keep-awake toggle and reset.
- **Storage** is `UserDefaults` in the shared App Group `group.com.sinkrundown.day1`, so the widget reads the same top 3 the app writes.
- **Widgets** (one widget, four sizes):
  - Small home-screen: block number, title, live countdown, "until 12:30", filled with the category colour.
  - Medium home-screen: the same plus the next block and today's top 3 with ticks.
  - Lock-screen rectangular: "06 · CrossFit", countdown, "until 12:30", next block.
  - Lock-screen inline: "06 · CrossFit · until 12:30".
  - The countdown is `Text(date, style: .timer)`, so it ticks without any reloads. The timeline has one entry per block boundary for the next 24 hours, so the widget flips at exactly 10:30:00. The timeline is rebuilt after local midnight so the odd/even day rule and the new day's top 3 apply.
- **Notifications** at each block start ("Block 07 · Calls + partners" / "until 15:15"), scheduled 24 hours ahead every time the app comes to the foreground. Permission is asked on first launch.

## Run the tests

From Terminal:

```bash
cd ios/RoutineCore && swift test
```

Or in Xcode: open `Day1.xcodeproj`, then Product → Test (⌘U). The Day1 scheme runs the RoutineCore tests.

## Run it on your own iPhone with a free Apple ID

You do not need a paid developer account to put this on your own phone.

1. **Add your Apple ID to Xcode.** Xcode → Settings → Accounts → "+" → Apple ID. Sign in. Xcode creates a "Personal Team" for you.

2. **Open the project.** Double-click `ios/Day1.xcodeproj`.

3. **Set the team on both targets.** In the project navigator click the blue "Day1" project icon, then under Targets pick **Day1** → "Signing & Capabilities" → Team → your name (Personal Team). Repeat for the **Day1WidgetExtension** target.

4. **Make the bundle identifiers yours.** Bundle IDs are unique across all Apple accounts. If Xcode reports that `com.sinkrundown.day1` is not available, change it on both targets, keeping the widget as the app's ID plus `.widget`:
   - Day1: `com.<yourname>.day1`
   - Day1WidgetExtension: `com.<yourname>.day1.widget`

   Then change the App Group to match in three places:
   - Both targets → Signing & Capabilities → App Groups → rename to `group.com.<yourname>.day1`
   - `RoutineCore/Sources/RoutineCore/RoutineStore.swift` → `appGroup`

   App Groups are supported on a Personal Team for iOS, so Xcode will register the group for you.

5. **Prepare the phone.**
   - Connect it with a cable (or enable Wi-Fi debugging after the first cabled run).
   - On the phone: Settings → Privacy & Security → Developer Mode → on, then restart.
   - Unlock the phone and tap "Trust" when asked.

6. **Run.** Pick your iPhone in the device menu at the top of Xcode and press ⌘R. The first run asks you to register the device; accept.

7. **Trust the developer certificate on the phone.** The first launch is blocked with "Untrusted Developer". On the phone: Settings → General → VPN & Device Management → your Apple ID → Trust. Then launch the app from the home screen.

8. **Add the widgets.** Long-press the home screen → "+" → search "Day 1" → choose small or medium. For the lock screen: long-press the lock screen → Customize → tap the widget area → "Day 1".

9. **Allow notifications** when the app asks on first launch. Block alerts are then scheduled by iOS itself and fire whether or not the app is running.

### Limits of a free Apple ID

- **The app expires after 7 days.** The provisioning profile Xcode creates lasts seven days. After that the icon still shows but the app will not open and the widgets go blank. Plug the phone in and press ⌘R again to re-sign it. Your data (top 3, learning log, ticks) is kept because it lives in the App Group container, which survives a reinstall of the same bundle ID.
- **Ten devices, three apps.** A Personal Team can have at most three apps installed at once and a limited number of registered devices.
- **No TestFlight, no App Store, no push notifications, no iCloud.** None of these are needed here; local notifications and App Groups work fine.
- Widgets sometimes need a minute after the first install to show real data. Adding the widget again or opening the app forces a refresh.

### If you later use a paid developer account (€99 / year)

- Set the team to your paid team on both targets. Nothing else in the project changes.
- Provisioning profiles last **one year** instead of seven days, so no weekly re-sign.
- You can distribute to yourself through **TestFlight** (builds last 90 days and update over the air) or as an **Ad Hoc** build, and you could publish on the App Store.
- Wireless debugging, more devices and no three-app limit.

## Editing the routine

Change the blocks in `RoutineCore/Sources/RoutineCore/Schedule.swift` (and keep `src/schedule.ts` in the web app in sync if you use both). The tests pin the current times, so update them too if you change block boundaries.

## How the widget stays exact

WidgetKit does not poll. `BlockProvider.getTimeline` builds one entry for right now and one for each block start or end in the next 24 hours, so iOS swaps to the next entry at precisely 10:30:00. Inside each entry the remaining time is a system timer text bound to the block's end date, which iOS updates every second on its own. The reload policy is `.after(local midnight)` so tomorrow's odd/even schedule and top 3 are picked up as the date changes; the app also asks for a reload whenever it comes to the foreground or you edit the top 3.
