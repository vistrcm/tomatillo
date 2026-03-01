import Foundation

class TomatilloTimer: ObservableObject {
    @Published var isRunning = false
    @Published var remaining: TimeInterval = 0
    @Published var finished = false

    var duration: TimeInterval = 25 * 60  // 25 minutes default

    var onFinished: (() -> Void)?

    private var timer: Timer?
    private let clock = ContinuousClock()
    private var deadline: ContinuousClock.Instant?

    func start() {
        remaining = duration
        isRunning = true
        finished = false
        deadline = clock.now + .seconds(duration)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let deadline = self.deadline else { return }
            let timeLeft = deadline - self.clock.now
            self.remaining = max(0, Double(timeLeft.components.seconds))
            if self.remaining <= 0 {
                self.stop()
                self.finished = true
                self.onFinished?()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        deadline = nil
        isRunning = false
        remaining = 0
    }
}
