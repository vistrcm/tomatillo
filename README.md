# Tomatillo

A vibecoded personal-use macOS pomodoro timer that lives in the menu bar and enforces breaks with a fullscreen curtain.

Inspired by [Just Focus](https://getjustfocus.com), created for specific usecase.

## Install

```bash
brew install --cask vistrcm/apps/tomatillo
```

Or download the latest signed and notarized `.app` from [Releases](https://github.com/vistrcm/tomatillo/releases), unzip, and drag to `/Applications`.


## How it works

1. A leaf icon appears in the menu bar — no Dock icon, no Cmd+Tab entry
2. A 25-minute work timer starts automatically
3. When it ends, a fullscreen curtain covers all displays with a random wallpaper
4. A binary dot display counts down the break (hover to see minutes:seconds)
5. When the break ends, only a "Next" button remains — click it when ready to work again

## Curtain controls

- **Snooze** — delay the break by 1 minute (one-time only)
- **Next** — skip remaining break, start working now
- **Lock** — lock the Mac screen

## Wallpaper

A random image is prefetched from [picsum.photos](https://picsum.photos) during the work session. If the download fails or takes too long, falls back to a local macOS wallpaper from `/System/Library/Desktop Pictures/`.
