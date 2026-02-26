import Foundation

class TomatilloTimer: ObservableObject {
    @Published var isRunning = false
    @Published var remaining: TimeInterval = 0

    var duration: TimeInterval = 25 * 60  // 25 minutes default

    var onFinished: (() -> Void)?

    private var timer: Timer?

    func start() {
        remaining = duration
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remaining -= 1
            if self.remaining <= 0 {
                self.stop()
                self.onFinished?()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remaining = 0
    }
}
