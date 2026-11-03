import Haptics
import UIKit

extension StoryCanvasView {
    enum Guide: Hashable {
        case centerX
        case centerY
        case left
        case right
        case top
        case bottom
    }

    static let snapDistance: CGFloat = 8

    var guideMargin: CGFloat {
        (bounds.width * 0.06).rounded()
    }

    func setUpGuides() {
        guidesLayer.fillColor = nil
        guidesLayer.strokeColor = UIColor(white: 1, alpha: 0.35).cgColor
        guidesLayer.lineWidth = 1
        guidesLayer.lineDashPattern = [4, 4]
        activeGuidesLayer.fillColor = nil
        activeGuidesLayer.strokeColor = UIColor.systemYellow.cgColor
        activeGuidesLayer.lineWidth = 1.5
        for layer in [guidesLayer, activeGuidesLayer] {
            layer.isHidden = true
            self.layer.addSublayer(layer)
        }
    }

    func setGuidesVisible(_ isVisible: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [guidesLayer, activeGuidesLayer] {
            layer.frame = bounds
            layer.isHidden = !isVisible
            self.layer.insertSublayer(layer, below: trash.layer)
        }
        guidesLayer.path = isVisible ? gridPath().cgPath : nil
        activeGuidesLayer.path = nil
        CATransaction.commit()
        activeGuides = []
    }

    func snap(_ raw: CGPoint, for view: UIView) -> CGPoint {
        let half = CGSize(width: view.frame.width / 2, height: view.frame.height / 2)
        let point = CGPoint(x: raw.x * bounds.width, y: raw.y * bounds.height)
        let margin = guideMargin
        let x = nearest(point.x, [
            (.centerX, bounds.width / 2),
            (.left, margin + half.width),
            (.right, bounds.width - margin - half.width),
        ])
        let y = nearest(point.y, [
            (.centerY, bounds.height / 2),
            (.top, margin + half.height),
            (.bottom, bounds.height - margin - half.height),
        ])
        showActive(Set([x.guide, y.guide].compactMap(\.self)))

        return CGPoint(x: x.value / max(bounds.width, 1), y: y.value / max(bounds.height, 1))
    }

    private func nearest(_ value: CGFloat, _ targets: [(Guide, CGFloat)]) -> (guide: Guide?, value: CGFloat) {
        let close = targets.min { left, right in
            abs(left.1 - value) < abs(right.1 - value)
        }
        guard let close, abs(close.1 - value) < Self.snapDistance else {
            return (nil, value)
        }

        return (close.0, close.1)
    }

    private func showActive(_ guides: Set<Guide>) {
        guard guides != activeGuides else {
            return
        }

        if !guides.subtracting(activeGuides).isEmpty {
            Haptics.play(.selection)
        }
        activeGuides = guides
        let path = UIBezierPath()
        for guide in guides {
            line(for: guide, in: path)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        activeGuidesLayer.path = path.cgPath
        CATransaction.commit()
    }

    private func gridPath() -> UIBezierPath {
        let path = UIBezierPath()
        for third in [CGFloat(1) / 3, CGFloat(2) / 3] {
            path.move(to: CGPoint(x: bounds.width * third, y: 0))
            path.addLine(to: CGPoint(x: bounds.width * third, y: bounds.height))
            path.move(to: CGPoint(x: 0, y: bounds.height * third))
            path.addLine(to: CGPoint(x: bounds.width, y: bounds.height * third))
        }
        let margin = guideMargin
        path.append(UIBezierPath(rect: bounds.insetBy(dx: margin, dy: margin)))

        return path
    }

    private func line(for guide: Guide, in path: UIBezierPath) {
        let margin = guideMargin
        let (start, end): (CGPoint, CGPoint) = switch guide {
        case .centerX:
            (CGPoint(x: bounds.midX, y: 0), CGPoint(x: bounds.midX, y: bounds.height))
        case .centerY:
            (CGPoint(x: 0, y: bounds.midY), CGPoint(x: bounds.width, y: bounds.midY))
        case .left:
            (CGPoint(x: margin, y: 0), CGPoint(x: margin, y: bounds.height))
        case .right:
            (CGPoint(x: bounds.width - margin, y: 0), CGPoint(x: bounds.width - margin, y: bounds.height))
        case .top:
            (CGPoint(x: 0, y: margin), CGPoint(x: bounds.width, y: margin))
        case .bottom:
            (CGPoint(x: 0, y: bounds.height - margin), CGPoint(x: bounds.width, y: bounds.height - margin))
        }
        path.move(to: start)
        path.addLine(to: end)
    }
}
