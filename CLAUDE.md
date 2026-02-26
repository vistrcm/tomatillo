# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Tomatillo

A macOS pomodoro focus timer that lives in the menu bar. When the work timer ends, a fullscreen "curtain" window covers all displays to enforce a break. The break timer counts down visually (binary dot display), then waits for the user to click "Next" to start the next work session.

SwiftUI MenuBarExtra + AppKit. No Xcode project — Swift Package Manager only.

## Build & Run

```bash
swift build
.build/debug/Tomatillo
```

For development with short timers:
```bash
./buildandrun.sh
```
This sets `TOMATILLO_WORK_SECS=7`, `TOMATILLO_BREAK_SECS=15`, `TOMATILLO_SNOOZE_SECS=5`.

Requires macOS 26 (Tahoe). Code is edited on Linux, built/run on Mac (arm64).

## Configuration

All via environment variables:

| Variable | Default | Description |
|---|---|---|
| `TOMATILLO_WORK_SECS` | 1500 (25 min) | Work session duration |
| `TOMATILLO_BREAK_SECS` | 420 (7 min) | Break duration |
| `TOMATILLO_SNOOZE_SECS` | 60 (1 min) | Snooze delay before curtain returns |

## Architecture

- **`TomatilloApp.swift`** — SwiftUI `@main` entry point. `MenuBarExtra` shows leaf (idle) or timer (running) icon. Start/Stop toggle, Quit. `AppDelegate` sets `.accessory` activation policy (no Dock icon). Wires `onFinished` → `CurtainController.show()`, `onNext` callback for the full work cycle restart. Reads env vars for configuration.

- **`TomatilloTimer.swift`** — `ObservableObject` with `@Published isRunning`, `remaining`, and `finished`. 1-second `Timer.scheduledTimer` countdown. Reused for both work timer (in `TomatilloApp`) and break timer (in `CurtainController`). Sets `finished = true` and calls `onFinished` when countdown hits zero.

- **`CurtainView.swift`** — The largest file, contains:
  - `KioskWindow` — `NSWindow` subclass overriding `canBecomeKey`/`canBecomeMain` (borderless windows can't become key by default).
  - `CurtainController` (singleton, `ObservableObject`) — manages the full curtain lifecycle:
    - `show(wallpaper:snoozed:)` — creates one `KioskWindow` per display, sets kiosk presentation options, starts break timer.
    - `hide()` — tears down windows, resets presentation options, returns to `.accessory` policy.
    - `snooze(wallpaper:)` — hides curtain, sets `@Published isSnoozed`, re-shows after `snoozeDuration` with same wallpaper and `snoozed: true` (hides snooze button).
    - `prefetchWallpaper(workDuration:)` — downloads random image from `picsum.photos` via `URLSession` when work timer starts. Timeout is `min(workDuration * 0.5, 60s)`. Falls back to local `/System/Library/Desktop Pictures/` if download fails.
    - `onNext` closure — set by `TomatilloApp`, handles full cycle restart (hide → start work timer → prefetch).
    - Break timer does NOT auto-advance. When break ends, UI shows only "Next" button. User clicks to start next cycle.
  - `CurtainButton` — reusable frosted-glass circular button (SF Symbol icon + label, `.ultraThinMaterial` background).
  - `CurtainContent` — break screen UI: binary dot timer (circles lit/dim), hover reveals M:SS text. During break: Snooze (one-time), Next, Lock Screen buttons. After break ends: only Next button visible.
  - `WallpaperBackground` — displays `NSImage` or black fallback.
  - `lockScreen()` — calls `SACLockScreenImmediate()` from private login framework via `dlopen`/`dlsym`.

### App lifecycle flow

```
Launch → work timer starts → prefetch wallpaper from picsum.photos
                ↓
Work timer ends → show() curtain on all screens → break timer starts
                ↓                                        ↓
        [Snooze] → hide, wait, re-show (no snooze btn)  |
        [Next]   → hide, restart work timer              |
        [Lock]   → lock macOS screen                     |
                                                         ↓
                                        Break ends → show only "Next" button
                                                         ↓
                                        User clicks Next → restart work timer
```

### Key patterns

- Curtain windows are AppKit-managed (`NSWindow` + `NSHostingView`) — SwiftUI's `Window` scene lacks control for kiosk behavior.
- Multi-monitor: iterate `NSScreen.screens`, one window per screen. Use `setFrame(screen.frame)` — do NOT pass `screen:` to NSWindow init (causes coordinate doubling).
- Window level: `CGShieldingWindowLevel()` + `.collectionBehavior = [.canJoinAllSpaces, .stationary]`.
- Activation policy toggling: `.accessory` (menu bar only) ↔ `.regular` (full app) so macOS respects kiosk presentation options.
- `orderOut` (hide) instead of `close` (destroy) avoids use-after-free crashes.
- `DispatchQueue.main.async` in `hide()` — defers cleanup when a button's action destroys its own window.
- Wallpaper prefetch: all `cachedWallpaper` access on main thread (URLSession completion dispatches to main). No locks needed.

## Menu bar states

- **Idle** — leaf icon, "Start" button
- **Working** — timer icon, "Stop" button
- **Snoozed** — timer icon, "Snoozed" text (informational, no action). `CurtainController.isSnoozed` drives this.
- **On break** — curtain covers screen, menu bar hidden by kiosk mode

## Release & Code Signing

Signing key lives on a YubiKey (PIV slot 9c, RSA 2048). Certificate: Developer ID Application.

### Release flow

```
git tag -s vX.Y.Z -m "Release notes"
./release.sh          # build, .app bundle, sign (YubiKey PIN), notarize, staple, zip
./gh-release.sh       # create GitHub release with zip + sha256
```

### release.sh checks

- HEAD must be an exact git tag
- Tag must be signed
- Tag must have annotation
- Working tree must be clean
- `AppIcon.icns` must exist

### Key files

| File | Purpose |
|------|---------|
| `release.sh` | Build + sign + notarize + staple + zip |
| `gh-release.sh` | Create GitHub release with artifact |
| `entitlements.plist` | Empty entitlements for distribution (no `get-task-allow`) |
| `Info.plist` | .app bundle metadata template (version injected from git tag) |
| `icon/convert-icon.sh` | Convert 1024x1024 PNG → `AppIcon.icns` via `sips` + `iconutil` |
| `icon/tomatillo-icon.svg` | SVG icon source |
| `icon/gemini-prompt.md` | Prompt for Gemini image generation |

### Bundle ID

`io.github.vistrcm.tomatillo`

### Notarization credentials

Stored in Keychain as profile `tomatillo-notary` via `xcrun notarytool store-credentials`.

## macOS Kiosk Mode

Presentation options: hideDock (2), hideMenuBar (8), disableProcessSwitching (32), disableForceQuit (64), disableHideApplication (256).

Key learnings:
- `.accessory` activation policy prevents macOS from respecting `disableProcessSwitching` — must toggle to `.regular` when curtain is shown
- `toggleFullScreen` is async (animated) — don't close the window before animation completes or it crashes
- `orderOut` (hide) instead of `close` (destroy) avoids use-after-free when a button destroys its own window mid-callback
- `enterFullScreenMode` on NSView is synchronous but doesn't create a proper Space
- `.focusEffectDisabled()` removes keyboard focus ring from custom buttons
