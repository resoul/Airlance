import UIKit

@MainActor
public final class LiquidSelectionView: UIView {
    private static let overflow: CGFloat = 16

    public var color = UIColor.systemBlue {
        didSet {
            guard color != oldValue else {
                return
            }

            canvas.color = color
            fallback.backgroundColor = color
            refresh()
        }
    }

    public var slots: [CGRect] = [] {
        didSet {
            guard slots != oldValue else {
                return
            }

            refresh()
        }
    }

    public private(set) var selectedIndex = 0

    private let canvas = LiquidCanvasView()
    private let fallback = UIView()
    private var head = Spring(0, stiffness: 22, dampingRatio: 0.62)
    private var tail = Spring(0, stiffness: 10, dampingRatio: 0.85)
    private var interactivePosition: CGFloat?

    private var target: CGFloat {
        interactivePosition ?? CGFloat(selectedIndex)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        canvas.color = color
        canvas.onFrame = { [weak self] deltaTime in
            self?.step(deltaTime)
        }
        addSubview(canvas)
        if !LiquidCanvasView.isSupported {
            addSubview(fallback)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func select(_ index: Int, animated: Bool) {
        interactivePosition = nil
        selectedIndex = index
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            head.reset(to: CGFloat(index))
            tail.reset(to: CGFloat(index))
            refresh()

            return
        }

        canvas.startFrames()
    }

    public func setInteractivePosition(_ position: CGFloat?) {
        let maximum = CGFloat(max(slots.count - 1, 0))
        interactivePosition = position.map { position in
            min(max(position, 0), maximum)
        }
        canvas.startFrames()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        canvas.frame = bounds.insetBy(dx: -Self.overflow, dy: -Self.overflow)
        refresh()
    }

    private func step(_ deltaTime: CFTimeInterval) {
        let target = target
        head.step(toward: target, deltaTime: deltaTime)
        if UIAccessibility.isReduceMotionEnabled {
            tail.reset(to: head.value)
        } else {
            tail.step(toward: target, deltaTime: deltaTime)
        }

        if head.isSettled(at: target), tail.isSettled(at: target) {
            head.reset(to: target)
            tail.reset(to: target)
            canvas.stopFrames()
        }
        updateShapes()
    }

    private func refresh() {
        updateShapes()
        canvas.render()
    }

    private func updateShapes() {
        guard !slots.isEmpty else {
            canvas.blobs = []
            canvas.bridges = []
            fallback.isHidden = true

            return
        }

        let offset = Self.overflow
        let headFrame = frame(at: head.value).offsetBy(dx: offset, dy: offset)
        let tailFrame = frame(at: tail.value).offsetBy(dx: offset, dy: offset)
        let stretch = abs(headFrame.midX - tailFrame.midX)
        let squeeze = 1 - min(stretch / (headFrame.width * 2.5), 0.3)
        let headDrop = headFrame.insetBy(dx: 0, dy: headFrame.height * (1 - squeeze) / 2)
        let tailDrop = tailFrame.insetBy(dx: tailFrame.width * 0.08, dy: tailFrame.height * (1 - squeeze * 0.85) / 2)

        canvas.blobs = [
            LiquidBlob(frame: headDrop, cornerRadius: headDrop.height / 2, blend: 0),
            LiquidBlob(frame: tailDrop, cornerRadius: tailDrop.height / 2, blend: tailDrop.height * 0.45),
        ]
        canvas.bridges = stretch > 2 ? [
            LiquidBridge(
                from: CGPoint(x: tailDrop.midX, y: tailDrop.midY),
                to: CGPoint(x: headDrop.midX, y: headDrop.midY),
                startRadius: tailDrop.height * 0.4,
                endRadius: headDrop.height * 0.45,
                blend: 6
            ),
        ] : []

        fallback.isHidden = false
        fallback.frame = frame(at: head.value)
        fallback.layer.cornerRadius = fallback.frame.height / 2
    }

    private func frame(at position: CGFloat) -> CGRect {
        let clamped = min(max(position, 0), CGFloat(slots.count - 1))
        let lower = Int(clamped.rounded(.down))
        let upper = min(lower + 1, slots.count - 1)
        let fraction = clamped - CGFloat(lower)
        let from = slots[lower]
        let to = slots[upper]

        return CGRect(
            x: from.minX + (to.minX - from.minX) * fraction,
            y: from.minY + (to.minY - from.minY) * fraction,
            width: from.width + (to.width - from.width) * fraction,
            height: from.height + (to.height - from.height) * fraction
        )
    }
}
