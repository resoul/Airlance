import Haptics
import UIKit

final class PhotoCropView: UIView {
    private static let minSide: CGFloat = 64
    private static let handleReach: CGFloat = 40

    private enum Drag {
        case move
        case corner(CGPoint)
    }

    private(set) var cropRect = CGRect.zero
    private var ratio: CGFloat?
    private var drag: Drag?
    private var dragStart = CGRect.zero
    private let shade = CAShapeLayer()
    private let border = CAShapeLayer()
    private let grid = CAShapeLayer()
    private let corners = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shade.fillRule = .evenOdd
        shade.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        border.fillColor = nil
        border.strokeColor = UIColor.white.cgColor
        border.lineWidth = 1
        grid.fillColor = nil
        grid.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
        grid.lineWidth = 0.5
        corners.fillColor = nil
        corners.strokeColor = UIColor.white.cgColor
        corners.lineWidth = 3
        for layer in [shade, grid, border, corners] {
            self.layer.addSublayer(layer)
        }
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panned(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var normalized: CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        return CGRect(
            x: cropRect.minX / bounds.width,
            y: cropRect.minY / bounds.height,
            width: cropRect.width / bounds.width,
            height: cropRect.height / bounds.height
        )
    }

    func reset(ratio: CGFloat?) {
        self.ratio = ratio
        guard let ratio else {
            cropRect = bounds
            redraw()

            return
        }

        var width = bounds.width
        var height = width / ratio
        if height > bounds.height {
            height = bounds.height
            width = height * ratio
        }
        cropRect = CGRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2, width: width, height: height)
        redraw()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if cropRect.isEmpty || !bounds.contains(cropRect) {
            reset(ratio: ratio)
        } else {
            redraw()
        }
    }

    private func redraw() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let outside = UIBezierPath(rect: bounds)
        outside.append(UIBezierPath(rect: cropRect))
        shade.path = outside.cgPath
        border.path = UIBezierPath(rect: cropRect).cgPath
        let lines = UIBezierPath()
        for step in 1...2 {
            let x = cropRect.minX + cropRect.width * CGFloat(step) / 3
            let y = cropRect.minY + cropRect.height * CGFloat(step) / 3
            lines.move(to: CGPoint(x: x, y: cropRect.minY))
            lines.addLine(to: CGPoint(x: x, y: cropRect.maxY))
            lines.move(to: CGPoint(x: cropRect.minX, y: y))
            lines.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        grid.path = lines.cgPath
        corners.path = cornerPath().cgPath
        CATransaction.commit()
    }

    private func cornerPath() -> UIBezierPath {
        let path = UIBezierPath()
        let length: CGFloat = 20
        let rect = cropRect.insetBy(dx: -1.5, dy: -1.5)
        let points = [
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: 1, y: 1)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: -1, y: 1)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: 1, y: -1)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: -1, y: -1)),
        ]
        for (point, direction) in points {
            path.move(to: CGPoint(x: point.x + direction.x * length, y: point.y))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x, y: point.y + direction.y * length))
        }

        return path
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            dragStart = cropRect
            drag = drag(at: gesture.location(in: self))
            Haptics.prepare(.selection)
        case .changed:
            let translation = gesture.translation(in: self)
            switch drag {
            case .move:
                move(by: translation)
            case .corner(let anchor):
                resize(anchor: anchor, by: translation)
            case nil:
                break
            }
            redraw()
        default:
            drag = nil
        }
    }

    private func drag(at point: CGPoint) -> Drag? {
        let candidates = [
            CGPoint(x: cropRect.minX, y: cropRect.minY),
            CGPoint(x: cropRect.maxX, y: cropRect.minY),
            CGPoint(x: cropRect.minX, y: cropRect.maxY),
            CGPoint(x: cropRect.maxX, y: cropRect.maxY),
        ]
        if let corner = candidates.first(where: { corner in
            hypot(corner.x - point.x, corner.y - point.y) < Self.handleReach
        }) {
            return .corner(CGPoint(x: corner.x == cropRect.minX ? 0 : 1, y: corner.y == cropRect.minY ? 0 : 1))
        }

        return cropRect.contains(point) ? .move : nil
    }

    private func move(by translation: CGPoint) {
        var rect = dragStart.offsetBy(dx: translation.x, dy: translation.y)
        rect.origin.x = min(max(rect.minX, 0), bounds.width - rect.width)
        rect.origin.y = min(max(rect.minY, 0), bounds.height - rect.height)
        cropRect = rect
    }

    private func resize(anchor: CGPoint, by translation: CGPoint) {
        var minX = dragStart.minX
        var maxX = dragStart.maxX
        var minY = dragStart.minY
        var maxY = dragStart.maxY
        if anchor.x == 0 {
            minX = min(max(0, minX + translation.x), maxX - Self.minSide)
        } else {
            maxX = max(min(bounds.width, maxX + translation.x), minX + Self.minSide)
        }
        if anchor.y == 0 {
            minY = min(max(0, minY + translation.y), maxY - Self.minSide)
        } else {
            maxY = max(min(bounds.height, maxY + translation.y), minY + Self.minSide)
        }
        if let ratio {
            let height = (maxX - minX) / ratio
            if anchor.y == 0 {
                minY = max(0, maxY - height)
            } else {
                maxY = min(bounds.height, minY + height)
            }
            let width = (maxY - minY) * ratio
            if anchor.x == 0 {
                minX = maxX - width
            } else {
                maxX = minX + width
            }
        }
        cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
