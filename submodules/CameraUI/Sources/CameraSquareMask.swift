import UIKit

final class CameraSquareMask: UIView {
    private let shade = CAShapeLayer()
    private let frameLine = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        shade.fillRule = .evenOdd
        shade.fillColor = UIColor.black.withAlphaComponent(0.62).cgColor
        frameLine.fillColor = nil
        frameLine.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        frameLine.lineWidth = 1
        layer.addSublayer(shade)
        layer.addSublayer(frameLine)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    static func square(in bounds: CGRect) -> CGRect {
        let side = min(bounds.width, bounds.height)

        return CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(rect: bounds)
        let square = Self.square(in: bounds)
        path.append(UIBezierPath(rect: square))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shade.frame = bounds
        shade.path = path.cgPath
        frameLine.frame = bounds
        frameLine.path = UIBezierPath(rect: square.insetBy(dx: 0.5, dy: 0.5)).cgPath
        CATransaction.commit()
    }
}

enum SquareCrop {
    static func crop(_ image: UIImage, preview: CGSize) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0, preview.width > 0, preview.height > 0 else {
            return image
        }

        let preview = (size.width > size.height) == (preview.width > preview.height)
            ? preview
            : CGSize(width: preview.height, height: preview.width)
        let scale = max(preview.width / size.width, preview.height / size.height)
        let side = min(preview.width, preview.height) / scale
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)

        return renderer.image { _ in
            image.draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }
    }
}
