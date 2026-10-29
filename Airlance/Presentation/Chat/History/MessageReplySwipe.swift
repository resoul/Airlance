import Haptics
import LiquidUI
import ListUI
import Theme
import UIKit

@MainActor
final class MessageReplySwipe: NSObject, UIGestureRecognizerDelegate {
    private static let threshold: CGFloat = 70

    var onReply: (@MainActor (String) -> Void)?
    var isEnabled = true

    private let pan = UIPanGestureRecognizer()
    private let effect = ReplySwipeEffect()
    private weak var list: ListView?
    private weak var node: MessageBubbleNode?
    private var isArmed = false

    init(list: ListView) {
        self.list = list
        super.init()
        pan.addTarget(self, action: #selector(panned(_:)))
        pan.delegate = self
        list.scrollView.addGestureRecognizer(pan)
        list.scrollView.panGestureRecognizer.require(toFail: pan)
        list.view.addSubview(effect)
    }

    func layout() {
        guard let list else {
            return
        }

        effect.frame = list.view.bounds
        list.view.bringSubviewToFront(effect)
    }

    func apply(_ theme: AppTheme) {
        effect.apply(color: theme.colors.textSecondary.withAlphaComponent(0.22), arrow: theme.colors.textPrimary)
    }

    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard isEnabled, gesture === pan, let list else {
            return false
        }

        let velocity = pan.velocity(in: list.scrollView)
        guard velocity.x < 0, abs(velocity.x) > abs(velocity.y) * 1.4 else {
            return false
        }

        let point = pan.location(in: list.scrollView)
        guard let node = list.node(atContentPoint: point) as? MessageBubbleNode, let frame = node.bubbleFrame else {
            return false
        }

        let local = CGPoint(x: point.x - node.frame.minX, y: point.y - node.frame.minY)
        guard frame.insetBy(dx: -6, dy: -4).contains(local) else {
            return false
        }

        self.node = node

        return true
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        guard let node else {
            return
        }

        switch gesture.state {
        case .changed:
            let dx = min(0, gesture.translation(in: gesture.view).x)
            let swipe = dx > -Self.threshold ? dx : -Self.threshold + (dx + Self.threshold) * 0.3
            let armed = swipe <= -Self.threshold
            if armed != isArmed {
                isArmed = armed
                if armed {
                    Haptics.play(.threshold)
                }
            }
            node.view.transform = CGAffineTransform(translationX: swipe, y: 0)
            effect.update(bubble: bubbleFrame(of: node), pull: -swipe, snapped: armed)
        case .ended, .cancelled, .failed:
            if isArmed, gesture.state == .ended, let id = node.itemID {
                onReply?(id)
            }
            finish(node)
        default:
            break
        }
    }

    private func finish(_ node: MessageBubbleNode) {
        isArmed = false
        self.node = nil
        effect.update(bubble: nil, pull: 0, snapped: false)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            node.view.transform = .identity
        }
    }

    private func bubbleFrame(of node: MessageBubbleNode) -> CGRect? {
        node.bubbleFrame.map { frame in
            node.view.convert(frame, to: effect)
        }
    }
}

private final class ReplySwipeEffect: UIView {
    private let canvas = LiquidCanvasView()
    private let arrow = UIImageView()
    private var bubble: CGRect?
    private var pull: CGFloat = 0
    private var isSnapped = false
    private var radius = Spring(0, stiffness: 18, dampingRatio: 0.45)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        canvas.gloss = 0.5
        canvas.rimWidth = 6
        canvas.onFrame = { [weak self] deltaTime in
            self?.step(deltaTime)
        }
        addSubview(canvas)
        let configuration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        arrow.image = UIImage(systemName: "arrowshape.turn.up.left.fill", withConfiguration: configuration)
        arrow.sizeToFit()
        arrow.alpha = 0
        addSubview(arrow)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        canvas.frame = bounds
    }

    func apply(color: UIColor, arrow arrowColor: UIColor) {
        canvas.color = color
        arrow.tintColor = arrowColor
    }

    func update(bubble: CGRect?, pull: CGFloat, snapped: Bool) {
        if snapped, !isSnapped {
            radius.velocity += 60
        }
        self.bubble = bubble
        self.pull = pull
        isSnapped = snapped
        if UIAccessibility.isReduceMotionEnabled {
            arrow.alpha = snapped ? 1 : 0
        }
        canvas.startFrames()
    }

    private func step(_ deltaTime: CFTimeInterval) {
        let target = bubble == nil ? 0 : (isSnapped ? 15 : min(pull / 70, 1) * 12)
        radius.step(toward: target, deltaTime: deltaTime)
        let value = max(radius.value, 0)
        if let bubble {
            let edge = CGPoint(x: bubble.maxX, y: bubble.midY)
            arrow.center = CGPoint(x: min(edge.x + 10 + pull * 0.35, bounds.width - 30), y: bubble.midY)
            arrow.alpha = isSnapped ? 1 : 0
            let stretches = !isSnapped && value > 1 && !UIAccessibility.isReduceMotionEnabled
            canvas.bridges = stretches ? [
                LiquidBridge(
                    from: CGPoint(x: edge.x - 4, y: edge.y),
                    to: arrow.center,
                    startRadius: max(2, 8 - pull / 14),
                    endRadius: value * 0.6,
                    blend: 5
                ),
            ] : []
        } else {
            canvas.bridges = []
            arrow.alpha = min(1, value / 10)
        }
        let center = arrow.center
        let circle = CGRect(x: center.x - value, y: center.y - value, width: value * 2, height: value * 2)
        canvas.blobs = value > 0.4 ? [LiquidBlob(frame: circle, cornerRadius: value, blend: 0)] : []
        if bubble == nil, value < 0.4 {
            radius.reset(to: 0)
            canvas.blobs = []
            canvas.render()
            canvas.stopFrames()
            arrow.alpha = 0
        }
    }
}
