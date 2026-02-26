# Tomatillo

A vibecoded personal-use macOS pomodoro timer that lives in the menu bar and enforces breaks with a fullscreen curtain.

Inspired by [Just Focus](https://getjustfocus.com), created for specific usecase.

## How it works

1. A leaf icon appears in the menu bar — no Dock icon, no Cmd+Tab entry
2. A 25-minute work timer starts automatically
3. When it ends, a fullscreen curtain covers all displays with a random wallpaper
4. A binary dot display counts down the break (hover to see minutes:seconds)
5. When the break ends, the next work session starts automatically

The loop runs hands-free: work → break → work → break → ...

## Curtain controls

- **Snooze** — delay the break by 1 minute (one-time only)
- **Next** — skip remaining break, start working now
- **Lock** — lock the Mac screen

## Build & run

Requires macOS 26 (Tahoe). Uses Swift Package Manager, no Xcode project needed.

```bash
swift build
.build/debug/Tomatillo
```

For development with short timers:

```bash
./buildandrun.sh
```

## Configuration

Set environment variables before launching:

```bash
export TOMATILLO_WORK_SECS=1500    # work session (default: 25 min)
export TOMATILLO_BREAK_SECS=420    # break duration (default: 7 min)
export TOMATILLO_SNOOZE_SECS=60    # snooze delay (default: 1 min)
```

## Wallpaper

A random image is prefetched from [picsum.photos](https://picsum.photos) during the work session. If the download fails or takes too long, falls back to a local macOS wallpaper from `/System/Library/Desktop Pictures/`.
