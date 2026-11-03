import Haptics
import UIKit

final class StoryTrackStrip: UIView {
    var onStart: (@MainActor (TimeInterval, Bool) -> Void)?

    private let bars = CAShapeLayer()
    private let fragment = UIView()
    private var samples: [Float] = []
    private var duration: TimeInterval = 1
    private var length: TimeInterval = 1
    private var start: TimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        bars.fillColor = UIColor(white: 1, alpha: 0.45).cgColor
        layer.addSublayer(bars)
        fragment.layer.borderColor = UIColor.white.cgColor
        fragment.layer.borderWidth = 2.5
        fragment.layer.cornerRadius = 8
        fragment.layer.cornerCurve = .continuous
        fragment.backgroundColor = UIColor(white: 1, alpha: 0.12)
        fragment.isUserInteractionEnabled = false
        addSubview(fragment)
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panned(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func set(samples: [Float], duration: TimeInterval, length: TimeInterval, start: TimeInterval) {
        self.samples = samples
        self.duration = max(duration, 0.1)
        self.length = min(length, self.duration)
        self.start = start
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width * CGFloat(length / duration)
        let x = bounds.width * CGFloat(start / duration)
        fragment.frame = CGRect(x: x, y: 0, width: max(width, 16), height: bounds.height)
        drawBars()
    }

    private func drawBars() {
        let path = UIBezierPath()
        let count = max(samples.count, 1)
        let step = bounds.width / CGFloat(count)
        for (index, sample) in samples.enumerated() {
            let height = max(3, CGFloat(sample) * (bounds.height - 12))
            path.append(UIBezierPath(
                roundedRect: CGRect(
                    x: CGFloat(index) * step + step * 0.2,
                    y: (bounds.height - height) / 2,
                    width: max(step * 0.6, 1),
                    height: height
                ),
                cornerRadius: 1.5
            ))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bars.frame = bounds
        bars.path = path.cgPath
        CATransaction.commit()
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        let shift = TimeInterval(gesture.translation(in: self).x / max(bounds.width, 1)) * duration
        gesture.setTranslation(.zero, in: self)
        start = min(max(start + shift, 0), max(duration - length, 0))
        setNeedsLayout()
        let isFinal = gesture.state == .ended || gesture.state == .cancelled
        if isFinal {
            Haptics.play(.selection)
        }
        onStart?(start, isFinal)
    }
}
