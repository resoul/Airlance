import CoreGraphics

public struct MenuGestureGate: Sendable {
    public static let threshold: CGFloat = 12

    public var isReady = false

    private var origin: CGPoint?
    private var isOpen = false

    public init() {}

    public mutating func allows(_ point: CGPoint) -> Bool {
        let origin = origin ?? point
        self.origin = origin
        if isReady, !isOpen, abs(point.y - origin.y) > Self.threshold {
            isOpen = true
        }

        return isOpen
    }
}
