import AppKit
import SwiftUI

/// Borderless windows can't become key by default.
/// Without key status, macOS ignores kiosk presentation options.
class KioskWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private let wallpaperDir = "/System/Library/Desktop Pictures"
private let wallpaperExtensions: Set<String> = ["heic", "jpg", "jpeg", "png"]

private func randomWallpaper() -> NSImage? {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: wallpaperDir) else { return nil }
    let images = files.filter { wallpaperExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
    guard let pick = images.randomElement() else { return nil }
    return NSImage(contentsOfFile: "\(wallpaperDir)/\(pick)")
}

class CurtainController {
    static let shared = CurtainController()

    private var windows: [NSWindow] = []
    private let breakTimer = TomatilloTimer()

    var breakDuration: TimeInterval = 7 * 60  // 7 minutes default
    var snoozeDuration: TimeInterval = 60     // 1 minute default
    var onNext: (() -> Void)?

    private var cachedWallpaper: NSImage?
    private var prefetchTask: URLSessionDataTask?

    private let kioskOptions: NSApplication.PresentationOptions = [
        .hideDock,
        .hideMenuBar,
        .disableProcessSwitching,
        .disableForceQuit,
        .disableHideApplication
    ]

    func prefetchWallpaper(workDuration: TimeInterval) {
        prefetchTask?.cancel()
        cachedWallpaper = nil

        guard let screen = NSScreen.main else { return }
        let scale = screen.backingScaleFactor
        let w = Int(screen.frame.width * scale)
        let h = Int(screen.frame.height * scale)
        guard let url = URL(string: "https://picsum.photos/\(w)/\(h)") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = min(workDuration * 0.5, 60)

        print("Prefetching wallpaper from \(url) (timeout: \(request.timeoutInterval)s)")

        prefetchTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self, let data, error == nil,
                  let image = NSImage(data: data) else {
                if let error { print("Wallpaper prefetch failed: \(error.localizedDescription)") }
                return
            }
            DispatchQueue.main.async {
                self.cachedWallpaper = image
                print("Wallpaper prefetched successfully")
            }
        }
        prefetchTask?.resume()
    }

    func show(wallpaper override: NSImage? = nil, snoozed: Bool = false) {
        let screens = NSScreen.screens
        if screens.isEmpty { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.presentationOptions = kioskOptions

        breakTimer.duration = breakDuration
        breakTimer.onFinished = { [weak self] in self?.onNext?() }
        breakTimer.start()

        let wallpaper: NSImage?
        if let override {
            wallpaper = override
        } else {
            prefetchTask?.cancel()
            prefetchTask = nil
            wallpaper = cachedWallpaper ?? randomWallpaper()
            cachedWallpaper = nil
        }

        for w in windows { w.orderOut(nil) }
        windows.removeAll()

        for (i, screen) in screens.enumerated() {
            let w = KioskWindow(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.setFrame(screen.frame, display: true)
            if i == 0 {
                w.contentView = NSHostingView(rootView: CurtainContent(
                    breakTimer: breakTimer,
                    wallpaper: wallpaper,
                    snoozed: snoozed,
                    onSnooze: { [weak self] in self?.snooze(wallpaper: wallpaper) },
                    onNext: { [weak self] in self?.onNext?() }
                ))
            } else {
                w.contentView = NSHostingView(rootView: WallpaperBackground(image: wallpaper))
            }
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            w.collectionBehavior = [.canJoinAllSpaces, .stationary]
            w.backgroundColor = .black
            w.isOpaque = true
            w.orderFrontRegardless()
            windows.append(w)
        }

        windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func snooze(wallpaper: NSImage?) {
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + snoozeDuration) { [weak self] in
            self?.show(wallpaper: wallpaper, snoozed: true)
        }
    }

    func hide() {
        breakTimer.stop()
        DispatchQueue.main.async {
            NSApp.presentationOptions = []
            for w in self.windows { w.orderOut(nil) }
            self.windows.removeAll()
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

private func lockScreen() {
    let lib = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
    guard let sym = dlsym(lib, "SACLockScreenImmediate") else { return }
    typealias LockFn = @convention(c) () -> Void
    unsafeBitCast(sym, to: LockFn.self)()
}

struct WallpaperBackground: View {
    let image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        } else {
            Color.black.ignoresSafeArea()
        }
    }
}

struct CurtainButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .shadow(radius: 4)
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

struct CurtainContent: View {
    @ObservedObject var breakTimer: TomatilloTimer
    let wallpaper: NSImage?
    let snoozed: Bool
    let onSnooze: () -> Void
    let onNext: () -> Void
    @State private var hovering = false

    private var bits: [Bool] {
        let n = max(Int(breakTimer.duration).bitWidth - Int(breakTimer.duration).leadingZeroBitCount, 1)
        let val = max(Int(breakTimer.remaining), 0)
        return (0..<n).reversed().map { val & (1 << $0) != 0 }
    }

    private var timeText: String {
        let t = Int(breakTimer.remaining)
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    var body: some View {
        ZStack {
            WallpaperBackground(image: wallpaper)
            VStack(spacing: 32) {
                ZStack {
                    HStack(spacing: 6) {
                        ForEach(Array(bits.enumerated()), id: \.offset) { _, on in
                            Circle()
                                .fill(on ? .white : .white.opacity(0.15))
                                .frame(width: 18, height: 18)
                                .shadow(color: on ? .white.opacity(0.6) : .clear, radius: 6)
                        }
                    }
                    .opacity(hovering ? 0 : 1)
                    Text(timeText)
                        .font(.system(size: 36, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                        .opacity(hovering ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.2), value: hovering)
                .onHover { hovering = $0 }
                HStack(spacing: 28) {
                    if !snoozed {
                        CurtainButton(icon: "moon.zzz", label: "Snooze", action: onSnooze)
                    }
                    CurtainButton(icon: "forward.fill", label: "Next", action: onNext)
                    CurtainButton(icon: "lock.fill", label: "Lock") { lockScreen() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
