import UIKit

extension ParticleChartView {
    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        touchArea?.contains(point) ?? super.point(inside: point, with: event)
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return
        }

        touch = point
        touchStart = (point, CACurrentMediaTime())
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touch = touches.first?.location(in: self)
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            touch = nil
            touchStart = nil
        }

        guard let point = touches.first?.location(in: self), let touchStart else {
            return
        }

        let moved = hypot(point.x - touchStart.point.x, point.y - touchStart.point.y)
        if moved < 12, CACurrentMediaTime() - touchStart.time < 0.4 {
            onTap?(point)
        }
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touch = nil
        touchStart = nil
    }
}
