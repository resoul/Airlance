@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
final class StoryRingNode: ASDisplayNode {
    private static let maxSegments = 30
    private static let spacing: CGFloat = 3

    private let seenGradient = CAGradientLayer()
    private let unseenGradient = CAGradientLayer()
    private let seenMask = CAShapeLayer()
    private let unseenMask = CAShapeLayer()
    private var ring: AvatarStoryRing?
    private var drawnSize: CGSize = .zero

    override func didLoad() {
        super.didLoad()
        isUserInteractionEnabled = false
        for (gradient, mask) in [(seenGradient, seenMask), (unseenGradient, unseenMask)] {
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
            mask.fillColor = nil
            mask.strokeColor = UIColor.black.cgColor
            mask.lineCap = .round
            gradient.mask = mask
            layer.addSublayer(gradient)
        }
    }

    func update(_ ring: AvatarStoryRing) {
        guard self.ring != ring else {
            return
        }

        self.ring = ring
        drawnSize = .zero
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        guard let ring, bounds.width > 0, drawnSize != bounds.size else {
            return
        }

        drawnSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for item in [seenGradient, unseenGradient, seenMask, unseenMask] {
            item.frame = bounds
        }
        let traits = view.traitCollection
        seenGradient.colors = ring.seenColors.map { color in
            color.resolvedColor(with: traits).cgColor
        }
        unseenGradient.colors = ring.unseenColors.map { color in
            color.resolvedColor(with: traits).cgColor
        }
        seenMask.lineWidth = ring.seenLineWidth
        unseenMask.lineWidth = ring.lineWidth
        let paths = Self.paths(for: ring, in: bounds)
        seenMask.path = paths.seen
        unseenMask.path = paths.unseen
        CATransaction.commit()
    }

    private static func paths(for ring: AvatarStoryRing, in bounds: CGRect) -> (seen: CGPath, unseen: CGPath) {
        let seen = CGMutablePath()
        let unseen = CGMutablePath()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - ring.lineWidth / 2
        let count = min(max(ring.totalCount, 1), maxSegments)
        let seenCount = count - min(max(ring.unseenCount, 0), count)
        guard count > 1 else {
            let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            (ring.hasUnseen ? unseen : seen).addEllipse(in: circle)

            return (seen, unseen)
        }

        let segment = 2 * CGFloat.pi / CGFloat(count)
        let gap = min((spacing + ring.lineWidth) / radius, segment / 2)
        for index in 0..<count {
            let start = -CGFloat.pi / 2 + segment * CGFloat(index) + gap / 2
            let path = index < seenCount ? seen : unseen
            path.move(to: CGPoint(x: center.x + radius * cos(start), y: center.y + radius * sin(start)))
            path.addArc(
                center: center,
                radius: radius,
                startAngle: start,
                endAngle: start + segment - gap,
                clockwise: false
            )
        }

        return (seen, unseen)
    }
}
