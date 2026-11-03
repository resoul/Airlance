import UIKit

final class TransferIndicator: CALayer {
    private static let side: CGFloat = 44
    private static let labelHeight: CGFloat = 18

    private let circle = CALayer()
    private let ring = CAShapeLayer()
    private let icon = CAShapeLayer()
    private let label = CATextLayer()
    private var isActive = false

    override init() {
        super.init()
        let side = Self.side
        circle.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        circle.cornerRadius = side / 2
        circle.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
        ring.frame = circle.bounds
        ring.path = UIBezierPath(ovalIn: circle.bounds.insetBy(dx: 3, dy: 3)).cgPath
        ring.fillColor = nil
        ring.strokeColor = UIColor.white.cgColor
        ring.lineWidth = 2.5
        ring.lineCap = .round
        ring.strokeEnd = 0
        icon.frame = circle.bounds
        icon.fillColor = nil
        icon.strokeColor = UIColor.white.cgColor
        icon.lineWidth = 2.2
        icon.lineCap = .round
        icon.lineJoin = .round
        label.alignmentMode = .center
        label.foregroundColor = UIColor.white.cgColor
        label.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
        label.cornerRadius = Self.labelHeight / 2
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.fontSize = 11
        label.isHidden = true
        circle.addSublayer(ring)
        circle.addSublayer(icon)
        addSublayer(circle)
        addSublayer(label)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func place(in frame: CGRect, scale contentsScale: CGFloat) {
        self.frame = frame
        label.contentsScale = contentsScale
        let side = min(Self.side, frame.width - 4, frame.height - 4)
        let scale = max(0.5, side / Self.side)
        circle.position = CGPoint(x: frame.width / 2, y: frame.height / 2)
        circle.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
    }

    func show(_ progress: TransferProgress?, reduceMotion: Bool) {
        let active = progress != nil
        if active != isActive {
            isActive = active
            icon.path = active ? Self.cross() : Self.arrow()
            spin(active && !reduceMotion)
        }
        ring.strokeEnd = CGFloat(progress?.fraction ?? 0)
        updateLabel(progress)
    }

    private func updateLabel(_ progress: TransferProgress?) {
        guard let progress, bounds.height >= 110, bounds.width >= 110 else {
            label.isHidden = true

            return
        }

        let done = ByteCountFormatter.string(fromByteCount: progress.done, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: progress.total, countStyle: .file)
        let text = "\(done) / \(total)"
        label.string = text
        let width = ceil((text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)]).width) + 20
        label.frame = CGRect(
            x: (bounds.width - width) / 2,
            y: circle.frame.maxY + 8,
            width: width,
            height: Self.labelHeight
        )
        label.isHidden = false
    }

    private func spin(_ active: Bool) {
        guard active else {
            ring.removeAnimation(forKey: "spin")

            return
        }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = -CGFloat.pi / 2
        rotation.toValue = CGFloat.pi * 1.5
        rotation.duration = 1.6
        rotation.repeatCount = .infinity
        ring.add(rotation, forKey: "spin")
    }

    private static func cross() -> CGPath {
        let center = side / 2
        let arm: CGFloat = 7
        let path = UIBezierPath()
        path.move(to: CGPoint(x: center - arm, y: center - arm))
        path.addLine(to: CGPoint(x: center + arm, y: center + arm))
        path.move(to: CGPoint(x: center + arm, y: center - arm))
        path.addLine(to: CGPoint(x: center - arm, y: center + arm))

        return path.cgPath
    }

    private static func arrow() -> CGPath {
        let center = side / 2
        let path = UIBezierPath()
        path.move(to: CGPoint(x: center, y: center - 10))
        path.addLine(to: CGPoint(x: center, y: center + 9))
        path.move(to: CGPoint(x: center - 7, y: center + 2))
        path.addLine(to: CGPoint(x: center, y: center + 9))
        path.addLine(to: CGPoint(x: center + 7, y: center + 2))

        return path.cgPath
    }
}
