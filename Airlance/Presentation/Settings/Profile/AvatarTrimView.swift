import AVFoundation
import UIKit

struct AvatarTrimRange: Equatable, Sendable {
    var start: Double
    var end: Double
}

final class AvatarTrimView: UIView {
    enum Edge {
        case start
        case end
        case whole
    }

    private static let handleWidth: CGFloat = 16
    private static let minimumLength = 1.0

    var onChange: (@MainActor (AvatarTrimRange, Edge) -> Void)?
    var onEnd: (@MainActor () -> Void)?

    private(set) var range = AvatarTrimRange(start: 0, end: 0)
    private var duration = 0.0
    private var maximumLength = 10.0
    private let strip = UIStackView()
    private let dimStart = UIView()
    private let dimEnd = UIView()
    private let frameView = UIView()
    private let startHandle = UIView()
    private let endHandle = UIView()
    private let playhead = UIView()
    private var dragging: Edge?
    private var dragOrigin = AvatarTrimRange(start: 0, end: 0)

    init(accent: UIColor) {
        super.init(frame: .zero)
        strip.axis = .horizontal
        strip.distribution = .fillEqually
        strip.clipsToBounds = true
        strip.layer.cornerRadius = 10
        addSubview(strip)
        for dim in [dimStart, dimEnd] {
            dim.backgroundColor = UIColor(white: 0, alpha: 0.6)
            addSubview(dim)
        }
        frameView.layer.borderColor = accent.cgColor
        frameView.layer.borderWidth = 3
        frameView.layer.cornerRadius = 10
        frameView.isUserInteractionEnabled = false
        addSubview(frameView)
        for handle in [startHandle, endHandle] {
            handle.backgroundColor = accent
            handle.layer.cornerRadius = 5
            handle.isUserInteractionEnabled = false
            addSubview(handle)
        }
        playhead.backgroundColor = .white
        playhead.isUserInteractionEnabled = false
        addSubview(playhead)
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panned(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(duration: Double, maximumLength: Double) {
        self.duration = max(duration, 0)
        self.maximumLength = maximumLength
        range = AvatarTrimRange(start: 0, end: min(self.duration, maximumLength))
        setNeedsLayout()
    }

    func setThumbnails(_ images: [UIImage]) {
        for view in strip.arrangedSubviews {
            view.removeFromSuperview()
        }
        for image in images {
            let view = UIImageView(image: image)
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            strip.addArrangedSubview(view)
        }
    }

    func setPlayhead(_ time: Double) {
        playhead.center.x = x(of: time)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        strip.frame = bounds
        let start = x(of: range.start)
        let end = x(of: range.end)
        let height = bounds.height
        dimStart.frame = CGRect(x: 0, y: 0, width: start, height: height)
        dimEnd.frame = CGRect(x: end, y: 0, width: bounds.width - end, height: height)
        frameView.frame = CGRect(x: start, y: 0, width: end - start, height: height)
        let width = Self.handleWidth
        startHandle.frame = CGRect(x: start - width / 2, y: 0, width: width, height: height)
        endHandle.frame = CGRect(x: end - width / 2, y: 0, width: width, height: height)
        playhead.frame = CGRect(x: playhead.center.x - 1, y: 2, width: 2, height: height - 4)
    }

    private func x(of time: Double) -> CGFloat {
        guard duration > 0 else {
            return 0
        }

        return bounds.width * CGFloat(time / duration)
    }

    private func edge(at point: CGPoint) -> Edge {
        let toStart = abs(point.x - x(of: range.start))
        let toEnd = abs(point.x - x(of: range.end))
        if min(toStart, toEnd) < 28 {
            return toStart < toEnd ? .start : .end
        }

        return .whole
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            dragging = edge(at: gesture.location(in: self))
            dragOrigin = range
        case .changed:
            guard let dragging, bounds.width > 0 else {
                return
            }

            let delta = Double(gesture.translation(in: self).x / bounds.width) * duration
            range = moved(dragging, by: delta)
            setNeedsLayout()
            onChange?(range, dragging)
        default:
            dragging = nil
            onEnd?()
        }
    }

    private func moved(_ edge: Edge, by delta: Double) -> AvatarTrimRange {
        var next = dragOrigin
        let minimum = min(Self.minimumLength, duration)
        switch edge {
        case .start:
            next.start = min(max(0, dragOrigin.start + delta), dragOrigin.end - minimum)
            next.end = min(next.end, next.start + maximumLength)
        case .end:
            next.end = max(min(duration, dragOrigin.end + delta), dragOrigin.start + minimum)
            next.start = max(next.start, next.end - maximumLength)
        case .whole:
            let length = dragOrigin.end - dragOrigin.start
            next.start = min(max(0, dragOrigin.start + delta), duration - length)
            next.end = next.start + length
        }

        return next
    }
}
