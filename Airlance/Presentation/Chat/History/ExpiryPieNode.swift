@preconcurrency import AsyncDisplayKit
import UIKit

final class ExpiryPieNode: ASDisplayNode {
    static let side: CGFloat = 11

    private let expiresAt: Date
    private let lifetime: TimeInterval
    private let color: UIColor

    init(expiresAt: Date, lifetime: TimeInterval, color: UIColor) {
        self.expiresAt = expiresAt
        self.lifetime = lifetime
        self.color = color
        super.init()
        isLayerBacked = true
    }

    override func didLoad() {
        super.didLoad()
        let bounds = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        let ring = CAShapeLayer()
        ring.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 0.6, dy: 0.6)).cgPath
        ring.fillColor = nil
        ring.strokeColor = color.cgColor
        ring.lineWidth = 1.2
        let pie = CAShapeLayer()
        let radius = Self.side / 4
        pie.path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        ).cgPath
        pie.fillColor = nil
        pie.strokeColor = color.cgColor
        pie.lineWidth = radius * 2
        let remaining = max(0, expiresAt.timeIntervalSinceNow)
        let fraction = lifetime > 0 ? min(1, remaining / lifetime) : 0
        pie.strokeEnd = 0
        let countdown = CABasicAnimation(keyPath: "strokeEnd")
        countdown.fromValue = fraction
        countdown.toValue = 0
        countdown.duration = max(0.01, remaining)
        pie.add(countdown, forKey: "countdown")
        layer.addSublayer(ring)
        layer.addSublayer(pie)
    }
}
