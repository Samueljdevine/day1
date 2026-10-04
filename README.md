# Day 1

A single-user daily routine tracker for your phone. It shows which block of the routine you should be in right now, how much time is left, and what comes next. No backend, no accounts, no analytics. Everything is stored in `localStorage` on the device and the app works fully offline once installed.

The program runs for 100 consecutive days, from Monday 5 October 2026 to Tuesday 12 January 2027. All times follow the phone's local clock, so the routine follows you between Ireland, Toronto and Bangkok without any settings.

## Native iOS app and widgets

The `ios/` folder holds the Phase 2 native app: a SwiftUI app with home-screen and lock-screen widgets that show the current block without opening anything. See [ios/README-iOS.md](ios/README-iOS.md) for how to run it on your iPhone with a free Apple ID.

## Edit the routine

All blocks, times, titles, notes and category colours live in [`src/schedule.ts`](src/schedule.ts). Change them there; nothing else needs to be touched. Block 10 (Ironman prep) runs on odd program days only; on even days block 9 extends to 18:30.

## Run locally

Requires Node 18 or newer.

```bash
npm install
npm run dev
```

Open the URL Vite prints (normally `http://localhost:5173`).

## Test

```bash
npm test
```

Runs the Vitest suite for `src/time.ts`: day numbers across the 25 October (Dublin) and 1 November (Toronto) clock changes, odd/even day block lists, the sleep state, exact block boundaries, countdown formatting and the learning streak.

## Build

```bash
npm run build
```

Type-checks with `tsc`, bundles to `dist/`, and generates the web manifest plus the service worker that precaches every asset. The whole build is well under 200 KB.

## Deploy to GitHub Pages

Pushing to `main` runs [`.github/workflows/pages.yml`](.github/workflows/pages.yml), which tests, builds with `BASE_PATH=/day1/` and publishes `dist/` to GitHub Pages at `https://samueljdevine.github.io/day1/`. That URL is HTTPS, so the app installs to the home screen and works offline.

Requirements: GitHub Pages must be enabled on the repository (Settings → Pages → Source: GitHub Actions). On a free GitHub plan Pages only works for public repositories.

The base path is read from the `BASE_PATH` environment variable at build time and defaults to `/`, so local `npm run dev` / `npm run preview` are unchanged.

## Serve `dist` on your home network (test on the phone)

The service worker needs a secure context. `localhost` counts, but a phone on the same Wi-Fi does not, so the app will still run over plain HTTP from a LAN address, but it will not install or work offline until it is served over HTTPS. Two options:

**Quick check (HTTP, no install):**

```bash
npm run preview
```

Vite prints a `Network:` URL such as `http://192.168.1.20:4173`. Open that on the phone. The countdown and all storage features work; the "Add to Home Screen" install will be a plain bookmark and offline mode will not be active.

**Full test with HTTPS (installable, offline):**

Any static host with HTTPS works: GitHub Pages, Netlify, Cloudflare Pages, or a home server with a certificate. Upload the contents of `dist/`. The app must be served from the root of the domain (or subdomain) because the manifest and service worker use `/` as their scope.

For a purely local HTTPS test you can use [mkcert](https://github.com/FiloSottile/mkcert) and any static server that accepts a certificate, for example:

```bash
mkcert -install
mkcert 192.168.1.20
npx serve dist --ssl-cert 192.168.1.20.pem --ssl-key 192.168.1.20-key.pem -l 8443
```

Install the mkcert root certificate on the phone first (mkcert prints where it lives; on iPhone AirDrop the `rootCA.pem`, install the profile, then enable it under Settings → General → About → Certificate Trust Settings).

## Install on the phone

**iPhone (Safari):** open the app URL in Safari → tap the Share button → "Add to Home Screen" → "Add". Launch it from the new "Day 1" icon. It opens full screen in portrait, with no browser chrome.

**Android (Chrome):** open the app URL in Chrome → tap the three-dot menu → "Install app" (or "Add to Home screen") → "Install".

After the first load the service worker caches everything, so the app opens and runs with no signal.

## Features

- **Now card:** current block, time remaining (updates every second, exact at boundaries), "until HH:MM", progress bar, block note. Under five minutes the countdown pulses and the bar turns amber. No sound.
- **Sleep state:** between 22:00 and 05:00 the screen dims to near-black and counts down to 05:00.
- **Next row:** the next block and its start time.
- **Top 3 for today:** three inputs with done ticks, saved as you type under `top3:<YYYY-MM-DD>`. During block 13 (20:00–21:00) a second set, "Tomorrow's top 3", saves under tomorrow's date so block 1 shows it the next morning.
- **Learning log:** during block 12 (19:15–20:00) a one-line "What did you learn?" field saves under `learn:<YYYY-MM-DD>`. The streak line counts consecutive days with an entry, ending today or yesterday.
- **Full day list:** every block with times and a done checkbox (`done:<YYYY-MM-DD>:<block>`). Current block highlighted, past blocks dimmed. Tap a block to preview it in the Now card for five seconds.
- **Keep screen awake:** uses the Screen Wake Lock API. The toggle is hidden on browsers that do not support it.
- **Reset today:** clears today's block checkboxes and top-3 ticks after a confirm. Text is kept.
- **Dark theme by default;** light theme when the phone prefers light.

## Block alerts (best effort)

"Enable block alerts" asks for notification permission (only when you tap it, never on load). While the app is open it schedules one local notification for the start of every remaining block today, for example "Block 07 · Calls + partners" / "until 15:15". Timers are rebuilt each time the app comes back to the foreground.

Limits to be aware of:

- **iPhone:** web notifications only work when the app is installed to the home screen (iOS 16.4 or later), and only fire while iOS keeps the app's process alive. If the app is not open, alerts may be delayed or missed. Treat them as a nice-to-have, not an alarm.
- **Android:** notifications are more reliable, but the page still has to be open or recently backgrounded for the timers to fire.

The Phase 2 native iOS app addresses this with a home-screen widget and system-scheduled notifications.

## Files

```
index.html            Page shell
src/main.ts           UI, clock loop, event wiring
src/schedule.ts       The routine (blocks, times, categories, colours)
src/time.ts           Pure time logic (day number, blocks for a date, current/next block, formatting, streak)
src/storage.ts        localStorage helpers
src/notify.ts         Local notification scheduling
src/styles.css        Theme, layout, sleep state
test/time.test.ts     Vitest suite
scripts/make-icons.mjs  Generates the PNG/SVG icons in public/ (npm run icons)
```
