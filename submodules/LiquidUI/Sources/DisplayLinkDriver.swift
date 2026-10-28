import QuartzCore

@MainActor
public final class DisplayLinkDriver {
    private let onFrame: @MainActor (CFTimeInterval) -> Void
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

    public var isRunning: Bool {
        link != nil
    }

    public init(onFrame: @escaping @MainActor (CFTimeInterval) -> Void) {
        self.onFrame = onFrame
    }

    public func start() {
        guard link == nil else {
            return
        }

        let link = CADisplayLink(target: DisplayLinkTarget(driver: self), selector: #selector(DisplayLinkTarget.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    public func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
    }

    fileprivate func tick(_ timestamp: CFTimeInterval) {
        let deltaTime = lastTimestamp.map { last in
            min(timestamp - last, 1.0 / 30)
        } ?? 1.0 / 60
        lastTimestamp = timestamp
        onFrame(deltaTime)
    }
}

@MainActor
private final class DisplayLinkTarget: NSObject {
    private weak var driver: DisplayLinkDriver?

    init(driver: DisplayLinkDriver) {
        self.driver = driver
    }

    @objc
    func tick(_ link: CADisplayLink) {
        guard let driver else {
            link.invalidate()

            return
        }

        driver.tick(link.timestamp)
    }
}
