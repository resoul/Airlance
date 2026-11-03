import UIKit

final class ShutterButton: UIView {
    static let side: CGFloat = 78

    private let ring = CAShapeLayer()
    private let progress = CAShapeLayer()
    private let core = UIView()
    private let glyph = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var idleColor = UIColor.white
    private var idleSide: CGFloat = 62

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        let bounds = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        ring.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 2.5, dy: 2.5)).cgPath
        ring.fillColor = nil
        ring.strokeColor = UIColor.white.cgColor
        ring.lineWidth = 5
        progress.path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: Self.side / 2 - 2.5,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        ).cgPath
        progress.fillColor = nil
        progress.strokeColor = UIColor.systemRed.cgColor
        progress.lineWidth = 5
        progress.lineCap = .round
        progress.strokeEnd = 0
        core.backgroundColor = .white
        core.isUserInteractionEnabled = false
        addSubview(core)
        glyph.contentMode = .center
        glyph.tintColor = .black
        core.addSubview(glyph)
        spinner.color = .black
        spinner.hidesWhenStopped = true
        addSubview(spinner)
        layer.addSublayer(ring)
        layer.addSublayer(progress)
        setRecording(false, limit: 0)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func press(_ isPressed: Bool) {
        UIView.animate(withDuration: 0.15) {
            self.core.transform = isPressed ? CGAffineTransform(scaleX: 0.88, y: 0.88) : .identity
        }
    }

    func setMode(_ mode: CameraMode) {
        let isVideo = mode == .video || mode == .dual
        idleColor = isVideo ? .systemRed : .white
        idleSide = isVideo ? 54 : 62
        let symbol: String? = switch mode {
        case .burst:
            "square.stack.3d.down.right.fill"
        case .loop:
            "infinity"
        case .photo, .video, .square, .dual:
            nil
        }
        glyph.image = symbol.map { name in
            UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold))
        } ?? nil
        UIView.animate(withDuration: 0.25) {
            self.core.backgroundColor = self.idleColor
            self.core.bounds = CGRect(x: 0, y: 0, width: self.idleSide, height: self.idleSide)
            self.core.layer.cornerRadius = self.idleSide / 2
            self.layoutGlyph()
        }
    }

    func setBusy(_ isBusy: Bool) {
        if isBusy {
            spinner.center = CGPoint(x: Self.side / 2, y: Self.side / 2)
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        glyph.alpha = isBusy ? 0 : 1
        isUserInteractionEnabled = !isBusy
    }

    private func layoutGlyph() {
        glyph.frame = core.bounds
    }

    func setRecording(_ isRecording: Bool, limit: TimeInterval) {
        let side: CGFloat = isRecording ? 30 : idleSide
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
            self.core.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            self.core.center = CGPoint(x: Self.side / 2, y: Self.side / 2)
            self.core.layer.cornerRadius = isRecording ? 8 : side / 2
            self.core.backgroundColor = isRecording ? .systemRed : self.idleColor
            self.core.transform = .identity
            self.glyph.alpha = isRecording ? 0 : 1
            self.layoutGlyph()
        }
        progress.removeAllAnimations()
        progress.strokeEnd = 0
        guard isRecording else {
            return
        }

        let fill = CABasicAnimation(keyPath: "strokeEnd")
        fill.fromValue = 0
        fill.toValue = 1
        fill.duration = limit
        fill.fillMode = .forwards
        fill.isRemovedOnCompletion = false
        progress.add(fill, forKey: "progress")
    }
}
