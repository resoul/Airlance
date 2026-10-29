import Haptics
import LiquidUI
import UIKit

struct QuickReplyCardContent {
    let title: String
    let message: String
    let draft: String
    let avatar: UIView
    let placeholder: String
    let pullHint: String
    let releaseHint: String
    let closeLabel: String
}

final class QuickReplyCardView: UIView {
    enum Mode {
        case entering
        case banner
        case reply
        case expanded
        case dismissing
    }

    static let bannerHeight: CGFloat = 86
    static let replyHeight: CGFloat = 184
    static let chatHeaderHeight: CGFloat = 66
    static let chatComposerHeight: CGFloat = 62

    var onSend: (@MainActor (String) -> Void)?
    var onOpenChat: (@MainActor (String) -> Void)?
    var onPrepareHistory: (@MainActor () -> UIView?)?
    var onReplyingChanged: (@MainActor (Bool) -> Void)?
    var onFinish: (@MainActor (String) -> Void)?

    let canvas = LiquidCanvasView()
    let content = UIView()
    let historyClip = UIView()
    let divider = UIView()
    let dim = UIView()
    let avatar: UIView
    let name = UIButton(type: .system)
    let message = UILabel()
    let field = UITextField()
    let send = UIButton(type: .system)
    let close = UIButton(type: .system)
    let hint = UILabel()
    let grabber = UIView()
    let texts: QuickReplyCardContent
    weak var historyView: UIView?
    var mode = Mode.entering
    var centerSpring = CardSpring(.zero, stiffness: 18, dampingRatio: 0.72)
    var halfSpring = CardSpring(CGPoint(x: 7, y: 7), stiffness: 18, dampingRatio: 0.72)
    var expansionSpring = Spring(0, stiffness: 15, dampingRatio: 0.86)
    var dragExpansion: CGFloat?
    var dragStartExpansion: CGFloat = 0
    var drag: CGFloat = 0
    var isArmed = false
    var phaseTime: CFTimeInterval = 0
    var scaleBase = CGSize(width: 1, height: 1)
    let keyboardTracker = UIView()
    var island = CGRect.zero
    var expiry: Task<Void, Never>?

    var isActive: Bool {
        mode != .dismissing
    }

    var isReplying: Bool {
        mode == .reply || mode == .expanded
    }

    var expansion: CGFloat {
        min(max(dragExpansion ?? expansionSpring.value, 0), 1)
    }

    var isExpansionSettled: Bool {
        dragExpansion == nil && expansionSpring.isSettled(at: mode == .expanded ? 1 : 0)
    }

    var islandMouth: CGPoint {
        CGPoint(x: island.midX, y: island.maxY)
    }

    var cardWidth: CGFloat {
        min(430, bounds.width - 28)
    }

    var cardTop: CGFloat {
        max(island.maxY + 14, safeAreaInsets.top + 8)
    }

    var chatHeight: CGFloat {
        let bottom = min(bounds.height - safeAreaInsets.bottom - 12, keyboardTop - 8)

        return max(Self.replyHeight, bottom - cardTop)
    }

    var cardHeight: CGFloat {
        isReplying ? Self.replyHeight + (chatHeight - Self.replyHeight) * expansion : Self.bannerHeight
    }

    var restingCenter: CGPoint {
        CGPoint(x: bounds.midX, y: cardTop + cardHeight / 2)
    }

    init(_ texts: QuickReplyCardContent) {
        self.texts = texts
        avatar = texts.avatar
        super.init(frame: .zero)
        buildViews()
        installKeyboardTracker()
        canvas.onFrame = { [weak self] deltaTime in
            self?.step(deltaTime)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var draft: String {
        field.text ?? ""
    }

    func start(in window: UIWindow) {
        window.addSubview(self)
        frame = window.bounds
        island = DynamicIslandGeometry.frame(in: window).insetBy(dx: 1.5, dy: 1.5)
        canvas.frame = bounds
        dim.frame = bounds
        layoutIfNeeded()
        centerSpring.position = islandMouth
        scaleBase = CGSize(width: cardWidth, height: Self.bannerHeight)
        content.alpha = 0
        animateChange()
        scheduleExpiry()
    }

    func update(message text: String) {
        message.text = text
        if mode == .banner || mode == .entering {
            scheduleExpiry()
        }
    }

    func dismiss() {
        guard isActive else {
            return
        }

        let wasReplying = isReplying
        mode = .dismissing
        expiry?.cancel()
        phaseTime = 0
        dragExpansion = nil
        scaleBase = content.bounds.size
        content.endEditing(true)
        if wasReplying {
            onReplyingChanged?(false)
        }
        UIView.animate(withDuration: 0.15) {
            self.dim.alpha = 0
            self.content.alpha = 0
        }
        if UIAccessibility.isReduceMotionEnabled || !LiquidCanvasView.isSupported {
            finish()
        } else {
            canvas.startFrames()
        }
    }

    func finish() {
        expiry?.cancel()
        canvas.stopFrames()
        removeFromSuperview()
        let completion = onFinish
        onFinish = nil
        completion?(draft)
    }

    func beginReply() {
        guard mode == .banner || mode == .entering else {
            return
        }

        mode = .reply
        expiry?.cancel()
        content.alpha = 1
        drag = 0
        if historyView == nil, let view = onPrepareHistory?() {
            historyView = view
            historyClip.addSubview(view)
        }
        updateControls()
        UIView.animate(withDuration: 0.2) {
            self.dim.alpha = 0.15
        }
        onReplyingChanged?(true)
        field.becomeFirstResponder()
        animateChange()
    }

    func setExpanded(_ value: Bool, velocity: CGFloat) {
        let changed = (mode == .expanded) != value
        expansionSpring.velocity = velocity
        mode = value ? .expanded : .reply
        if changed, value {
            Haptics.play(.menu)
        }
        updateControls()
        animateChange()
    }

    func sendReply() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        onSend?(text)
        field.text = ""
        Haptics.play(.success)
        updateControls()
    }

    func scheduleExpiry() {
        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            self?.dismiss()
        }
    }

    func animateChange() {
        guard !UIAccessibility.isReduceMotionEnabled, LiquidCanvasView.isSupported else {
            snap()

            return
        }

        canvas.startFrames()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard isActive else {
            return false
        }

        return isReplying || content.frame.insetBy(dx: -8, dy: -8).contains(point)
    }

    override func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard let pan = gesture as? UIPanGestureRecognizer else {
            return true
        }

        let velocity = pan.velocity(in: self)

        return abs(velocity.y) > abs(velocity.x)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if isReplying {
            animateChange()
        }
    }

    @objc
    private func keyboardChanged(_ notification: Notification) {
        if isReplying {
            animateChange()
        }
    }
}

struct CardSpring {
    private var x: Spring
    private var y: Spring

    var position: CGPoint {
        get {
            CGPoint(x: x.value, y: y.value)
        }
        set {
            x.reset(to: newValue.x)
            y.reset(to: newValue.y)
        }
    }

    var speed: CGFloat {
        hypot(x.velocity, y.velocity)
    }

    init(_ position: CGPoint, stiffness: CGFloat, dampingRatio: CGFloat) {
        x = Spring(position.x, stiffness: stiffness, dampingRatio: dampingRatio)
        y = Spring(position.y, stiffness: stiffness, dampingRatio: dampingRatio)
    }

    mutating func step(toward target: CGPoint, deltaTime: CFTimeInterval) {
        x.step(toward: target.x, deltaTime: deltaTime)
        y.step(toward: target.y, deltaTime: deltaTime)
    }
}
