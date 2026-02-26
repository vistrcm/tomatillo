import SwiftUI

@main
struct TomatilloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var timer = TomatilloTimer()
    @ObservedObject private var curtain = CurtainController.shared

    init() {
        let t = TomatilloTimer()
        if let val = ProcessInfo.processInfo.environment["TOMATILLO_WORK_SECS"],
           let secs = TimeInterval(val) {
            t.duration = secs
        }
        if let val = ProcessInfo.processInfo.environment["TOMATILLO_BREAK_SECS"],
           let secs = TimeInterval(val) {
            CurtainController.shared.breakDuration = secs
        }
        if let val = ProcessInfo.processInfo.environment["TOMATILLO_SNOOZE_SECS"],
           let secs = TimeInterval(val) {
            CurtainController.shared.snoozeDuration = secs
        }
        t.onFinished = { CurtainController.shared.show() }
        CurtainController.shared.onNext = { [weak t] in
            guard let t else { return }
            CurtainController.shared.hide()
            t.onFinished = { CurtainController.shared.show() }
            t.start()
            CurtainController.shared.prefetchWallpaper(workDuration: t.duration)
        }
        t.start()
        CurtainController.shared.prefetchWallpaper(workDuration: t.duration)
        _timer = StateObject(wrappedValue: t)
    }

    var body: some Scene {
        MenuBarExtra {
            if curtain.isSnoozed {
                Text("Snoozed")
            } else if timer.isRunning {
                Button("Stop") { timer.stop() }
            } else {
                Button("Start") {
                    timer.onFinished = { CurtainController.shared.show() }
                    timer.start()
                    CurtainController.shared.prefetchWallpaper(workDuration: timer.duration)
                }
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: timer.isRunning || curtain.isSnoozed ? "timer" : "leaf")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
