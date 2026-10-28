import CoreGraphics
import QuartzCore

public struct Spring: Sendable {
    public var value: CGFloat
    public var velocity: CGFloat = 0
    public var stiffness: CGFloat
    public var dampingRatio: CGFloat

    public init(_ value: CGFloat, stiffness: CGFloat, dampingRatio: CGFloat) {
        self.value = value
        self.stiffness = stiffness
        self.dampingRatio = dampingRatio
    }

    public mutating func step(toward target: CGFloat, deltaTime: CFTimeInterval) {
        let steps = max(1, Int((deltaTime * 480).rounded(.up)))
        let dt = CGFloat(deltaTime) / CGFloat(steps)
        for _ in 0..<steps {
            let force = stiffness * stiffness * (target - value) - 2 * dampingRatio * stiffness * velocity
            velocity += force * dt
            value += velocity * dt
        }
    }

    public mutating func reset(to value: CGFloat) {
        self.value = value
        velocity = 0
    }

    public func isSettled(at target: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
        abs(value - target) < tolerance && abs(velocity) < tolerance * 10
    }
}
