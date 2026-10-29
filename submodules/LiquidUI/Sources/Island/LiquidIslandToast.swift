import Haptics
import UIKit

@MainActor
public final class LiquidIslandToast: UIView, UITextFieldDelegate {
    private enum Phase {
        case emerging
        case shown
        case dismissing
        case finished
    }

    private static let gap: CGFloat = 14
    private static weak var current: LiquidIslandToast?

    public var onTap: (@MainActor () -> Void)?
    public var onReply: (@MainActor (String) -> Void)?

    private let canvas = LiquidCanvasView()
    private let content: LiquidIslandContentView
    private let duration: TimeInterval
    private let isRepliable: Bool
    private var island = CGRect.zero
    private var width: CGFloat = 340
    private var phase = Phase.emerging
    private var phaseTime: CFTimeInterval = 0
    private var shownTime: CFTimeInterval = 0
    private var pill = IslandPill(center: .zero)
    private var neck: CGFloat = 22
    private var isTornOff = false
    private var recoilTime: CFTimeInterval?
    private var drag: CGPoint?
    private var isExpanded = false
    private var isSent = false

    public var isReplying: Bool {
        isExpanded && (phase == .emerging || phase == .shown)
    }

    private var height: CGFloat {
        isExpanded ? LiquidIslandContentView.expandedHeight : LiquidIslandContentView.compactHeight
    }

    private var mouth: CGPoint {
        CGPoint(x: island.midX, y: island.maxY)
    }

    private var restCenter: CGPoint {
        CGPoint(x: island.midX, y: island.maxY + Self.gap + height / 2)
    }

    private var fullSize: CGSize {
        CGSize(width: width / 2, height: height / 2)
    }

    @discardableResult
    public static func show(
        _ content: LiquidIslandContent,
        in window: UIWindow,
        duration: TimeInterval = 5
    ) -> LiquidIslandToast? {
        guard LiquidCanvasView.isSupported else {
            return nil
        }

        current?.dismiss()
        let toast = LiquidIslandToast(content, duration: duration)
        toast.install(in: window)
        current = toast

        return toast
    }

    private init(_ content: LiquidIslandContent, duration: TimeInterval) {
        self.content = LiquidIslandContentView(content)
        self.duration = duration
        isRepliable = content.replyPlaceholder != nil
        super.init(frame: .zero)
        canvas.color = .black
        canvas.gloss = 0.5
        canvas.rimWidth = 10
        addSubview(canvas)
        self.content.alpha = 0
        self.content.replyField.delegate = self
        addSubview(self.content)
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panned(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        canvas.onFrame = { [weak self] deltaTime in
            self?.update(deltaTime)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func dismiss() {
        guard phase == .emerging || phase == .shown else {
            return
        }

        phase = .dismissing
        phaseTime = 0
        drag = nil
        if content.replyField.isFirstResponder {
            content.replyField.resignFirstResponder()
        }
        if isSent {
            pill.shoot()
        }
        UIView.animate(withDuration: 0.12) {
            self.content.alpha = 0
        }
    }

    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard phase == .emerging || phase == .shown else {
            return false
        }

        let size = pill.halfSize

        return abs(point.x - pill.x.value) <= size.width && abs(point.y - pill.y.value) <= size.height + 6
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return false
        }

        isSent = true
        onReply?(text)
        Haptics.play(.tap)
        dismiss()

        return false
    }

    private func install(in window: UIWindow) {
        window.addSubview(self)
        frame = window.bounds
        island = DynamicIslandGeometry.frame(in: window).insetBy(dx: 1.5, dy: 1.5)
        width = min(window.bounds.width - 24, 360)
        canvas.frame = CGRect(x: 0, y: 0, width: window.bounds.width, height: island.maxY + 300)
        content.bounds = CGRect(x: 0, y: 0, width: width, height: LiquidIslandContentView.expandedHeight)
        pill = IslandPill(center: CGPoint(x: island.midX, y: island.maxY - 6))
        canvas.startFrames()
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        guard phase == .emerging || phase == .shown else {
            return
        }

        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .began, .changed:
            drag = CGPoint(x: translation.x * 0.4, y: translation.y < 0 ? translation.y : translation.y * 0.35)
        default:
            let isFlung = gesture.velocity(in: self).y < -400 || translation.y < -30
            drag = nil
            if isFlung {
                dismiss()
            } else {
                shownTime = 0
            }
        }
    }

    @objc
    private func tapped() {
        guard !isExpanded else {
            return
        }

        guard isRepliable else {
            pill.squash()
            onTap?()

            return
        }

        isExpanded = true
        pill.halfHeight.velocity += 80
        content.showField()
    }

    private func update(_ deltaTime: CFTimeInterval) {
        phaseTime += deltaTime
        var target = (center: restCenter, size: fullSize)
        switch phase {
        case .emerging:
            target = emerge(target)
        case .shown:
            if drag == nil, !isExpanded {
                shownTime += deltaTime
                if shownTime > duration {
                    dismiss()
                }
            }
        case .dismissing:
            target = sink()
        case .finished:
            if phaseTime > 0.9 {
                canvas.stopFrames()
                removeFromSuperview()

                return
            }
        }
        if let drag {
            let stretch = max(drag.y, 0)
            target.center = CGPoint(x: restCenter.x + drag.x, y: restCenter.y + drag.y)
            target.size = CGSize(width: fullSize.width - stretch * 0.25, height: fullSize.height + stretch * 0.45)
        }
        pill.step(center: target.center, halfSize: target.size, deltaTime: deltaTime)
        if let time = recoilTime {
            recoilTime = time > 1 ? nil : time + deltaTime
        }
        draw()
    }

    private func emerge(_ rest: (center: CGPoint, size: CGSize)) -> (center: CGPoint, size: CGSize) {
        neck = 22 * max(0, 1 - max(0, phaseTime - 0.2) / 0.22)
        if neck == 0, !isTornOff {
            isTornOff = true
            recoilTime = 0
            Haptics.play(.threshold)
        }
        if pill.halfWidth.value > fullSize.width * 0.82, content.alpha == 0 {
            UIView.animate(withDuration: 0.18) {
                self.content.alpha = 1
            }
        }
        if phaseTime > 0.75 {
            phase = .shown
            shownTime = 0
        }
        guard phaseTime < 0.2 else {
            return rest
        }

        return (CGPoint(x: mouth.x, y: mouth.y + 20), CGSize(width: 14, height: 14))
    }

    private func sink() -> (center: CGPoint, size: CGSize) {
        let size = phaseTime > 0.08 ? CGSize(width: 11, height: 11) : fullSize
        let center = phaseTime > 0.16 ? CGPoint(x: mouth.x, y: mouth.y + 6) : pill.center
        let distance = pill.distance(to: mouth)
        neck = distance < 70 ? 20 : 0
        if distance < 16, pill.halfWidth.value < 16 {
            phase = .finished
            phaseTime = 0
            recoilTime = 0
            Haptics.play(.tap)
        }

        return (center, size)
    }

    private func draw() {
        var blobs = [LiquidBlob(frame: island, cornerRadius: island.height / 2, blend: 0)]
        if phase != .finished {
            blobs.append(pill.blob(blend: neck))
        }
        if let recoilTime {
            blobs.append(IslandPill.recoil(at: mouth, time: recoilTime))
        }
        canvas.blobs = blobs
        let full = fullSize
        let scaleX = max(pill.halfWidth.value / full.width, 0.01)
        let scaleY = max(pill.halfHeight.value / full.height, 0.01)
        content.center = CGPoint(
            x: pill.x.value,
            y: pill.y.value + (LiquidIslandContentView.expandedHeight - height) / 2 * scaleY
        )
        content.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
    }
}
