import CoreGraphics
import QuartzCore

@MainActor
public final class SpringAnimator {
    public var onChange: (@MainActor (CGFloat) -> Void)?

    private var spring: Spring
    private var target: CGFloat
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.step(deltaTime)
    }

    public var value: CGFloat {
        spring.value
    }

    public init(value: CGFloat, stiffness: CGFloat, dampingRatio: CGFloat) {
        spring = Spring(value, stiffness: stiffness, dampingRatio: dampingRatio)
        target = value
    }

    public func animate(to target: CGFloat) {
        self.target = target
        guard !spring.isSettled(at: target) else {
            return
        }

        driver.start()
    }

    public func set(_ value: CGFloat) {
        driver.stop()
        target = value
        spring.reset(to: value)
        onChange?(value)
    }

    private func step(_ deltaTime: CFTimeInterval) {
        spring.step(toward: target, deltaTime: deltaTime)
        if spring.isSettled(at: target) {
            spring.reset(to: target)
            driver.stop()
        }
        onChange?(spring.value)
    }
}
