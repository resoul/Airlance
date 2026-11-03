import UIKit

final class AudioScrubberView: UIView {
    var onSeek: (@MainActor (Double) -> Void)?
    private(set) var isDragging = false
    private let track = UIView()
    private let fill = UIView()
    private let knob = UIView()
    private var value: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        for view in [track, fill, knob] {
            view.isUserInteractionEnabled = false
            addSubview(view)
        }
        track.layer.cornerRadius = 2
        fill.layer.cornerRadius = 2
        knob.layer.cornerRadius = 7
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panned(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(track color: UIColor, fill accent: UIColor) {
        track.backgroundColor = color
        fill.backgroundColor = accent
        knob.backgroundColor = accent
    }

    func set(_ value: Double) {
        guard !isDragging else {
            return
        }

        self.value = value
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let midY = bounds.midY
        let knobSize: CGFloat = isDragging ? 18 : 14
        track.frame = CGRect(x: 0, y: midY - 2, width: width, height: 4)
        let x = width * CGFloat(min(1, max(0, value)))
        fill.frame = CGRect(x: 0, y: midY - 2, width: x, height: 4)
        knob.bounds = CGRect(x: 0, y: 0, width: knobSize, height: knobSize)
        knob.layer.cornerRadius = knobSize / 2
        knob.center = CGPoint(x: x, y: midY)
    }

    private func fraction(_ point: CGPoint) -> Double {
        bounds.width > 0 ? Double(min(1, max(0, point.x / bounds.width))) : 0
    }

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isDragging = true
            value = fraction(gesture.location(in: self))
        case .changed:
            value = fraction(gesture.location(in: self))
        case .ended:
            isDragging = false
            onSeek?(value)
        default:
            isDragging = false
        }
        setNeedsLayout()
        UIView.animate(withDuration: 0.12) {
            self.layoutIfNeeded()
        }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        value = fraction(gesture.location(in: self))
        setNeedsLayout()
        onSeek?(value)
    }
}
