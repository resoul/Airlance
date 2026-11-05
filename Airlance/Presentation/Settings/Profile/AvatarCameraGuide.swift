import UIKit

enum AvatarFraming {
    static func fraction(content: CGSize, preview: CGSize?) -> CGFloat {
        guard let preview, content.width > 0, content.height > 0, preview.width > 0, preview.height > 0 else {
            return 1
        }

        let isSameOrientation = (content.width > content.height) == (preview.width > preview.height)
        let shown = isSameOrientation ? preview : CGSize(width: preview.height, height: preview.width)
        let scale = max(shown.width / content.width, shown.height / content.height)
        let side = min(shown.width, shown.height) / scale

        return min(1, max(0.1, side / min(content.width, content.height)))
    }
}

final class AvatarCameraGuide: UIView {
    private let outerShade = CAShapeLayer()
    private let cornerShade = CAShapeLayer()
    private let grid = CAShapeLayer()
    private let frameLine = CAShapeLayer()
    private let circleLine = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        outerShade.fillRule = .evenOdd
        outerShade.fillColor = UIColor(white: 0, alpha: 0.62).cgColor
        cornerShade.fillRule = .evenOdd
        cornerShade.fillColor = UIColor(white: 0, alpha: 0.32).cgColor
        for line in [grid, frameLine, circleLine] {
            line.fillColor = nil
            line.lineWidth = 1
        }
        grid.strokeColor = UIColor(white: 1, alpha: 0.28).cgColor
        frameLine.strokeColor = UIColor(white: 1, alpha: 0.5).cgColor
        circleLine.strokeColor = UIColor.white.cgColor
        circleLine.lineWidth = 2
        for sublayer in [outerShade, cornerShade, grid, frameLine, circleLine] {
            layer.addSublayer(sublayer)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        let square = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        let outer = UIBezierPath(rect: bounds)
        outer.append(UIBezierPath(rect: square))
        let corners = UIBezierPath(rect: square)
        corners.append(UIBezierPath(ovalIn: square))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outerShade.path = outer.cgPath
        cornerShade.path = corners.cgPath
        grid.path = Self.gridPath(in: square).cgPath
        frameLine.path = UIBezierPath(rect: square.insetBy(dx: 0.5, dy: 0.5)).cgPath
        circleLine.path = UIBezierPath(ovalIn: square.insetBy(dx: 1, dy: 1)).cgPath
        CATransaction.commit()
    }

    private static func gridPath(in square: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        for step in 1...2 {
            let offset = square.width * CGFloat(step) / 3
            path.move(to: CGPoint(x: square.minX + offset, y: square.minY))
            path.addLine(to: CGPoint(x: square.minX + offset, y: square.maxY))
            path.move(to: CGPoint(x: square.minX, y: square.minY + offset))
            path.addLine(to: CGPoint(x: square.maxX, y: square.minY + offset))
        }

        return path
    }
}
