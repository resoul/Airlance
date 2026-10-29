import CoreGraphics
import QuartzCore

struct IslandPill {
    var x: Spring
    var y: Spring
    var halfWidth = Spring(6, stiffness: 17, dampingRatio: 0.4)
    var halfHeight = Spring(6, stiffness: 17, dampingRatio: 0.4)

    var center: CGPoint {
        CGPoint(x: x.value, y: y.value)
    }

    var halfSize: CGSize {
        CGSize(width: max(halfWidth.value, 1), height: max(halfHeight.value, 1))
    }

    init(center: CGPoint) {
        x = Spring(center.x, stiffness: 15, dampingRatio: 0.55)
        y = Spring(center.y, stiffness: 15, dampingRatio: 0.55)
    }

    mutating func step(center target: CGPoint, halfSize size: CGSize, deltaTime: CFTimeInterval) {
        x.step(toward: target.x, deltaTime: deltaTime)
        y.step(toward: target.y, deltaTime: deltaTime)
        halfWidth.step(toward: size.width, deltaTime: deltaTime)
        halfHeight.step(toward: size.height, deltaTime: deltaTime)
    }

    mutating func shoot() {
        x.stiffness = 26
        y.stiffness = 26
        x.dampingRatio = 0.7
        y.dampingRatio = 0.7
    }

    mutating func squash() {
        halfWidth.velocity += 140
        halfHeight.velocity -= 160
    }

    func distance(to point: CGPoint) -> CGFloat {
        hypot(x.value - point.x, y.value - point.y)
    }

    func blob(blend: CGFloat) -> LiquidBlob {
        let size = halfSize
        let frame = CGRect(
            x: x.value - size.width,
            y: y.value - size.height,
            width: size.width * 2,
            height: size.height * 2
        )

        return LiquidBlob(frame: frame, cornerRadius: min(size.width, size.height, 32), blend: blend)
    }

    static func recoil(at mouth: CGPoint, time: CFTimeInterval) -> LiquidBlob {
        let extent = 11 * exp(-7 * time) * cos(18 * time)
        let center = CGPoint(x: mouth.x, y: mouth.y - 7 + max(extent, -4))
        let frame = CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)

        return LiquidBlob(frame: frame, cornerRadius: 7, blend: 10)
    }
}
