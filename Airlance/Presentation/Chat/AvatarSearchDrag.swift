import Haptics
import LiquidUI
import UIKit

@MainActor
final class AvatarSearchDrag: NSObject {
    private enum Phase {
        case idle
        case dragging
        case returning
        case morphing
    }

    private static let threshold: CGFloat = 0.75
    private static let backCenter: CGFloat = 42
    private static let fieldHeight: CGFloat = 36
    private static let fieldTrailing: CGFloat = 96

    var onSearch: (@MainActor () -> Void)?
    var tint = UIColor.systemBlue

    private weak var button: ChatAvatarButton?
    private let overlay = UIView()
    private let canvas = LiquidCanvasView()
    private let face = UIImageView()
    private let lens = UIImageView()
    private var phase = Phase.idle
    private var anchor = CGPoint.zero
    private var radius: CGFloat = 18
    private var field = CGRect.zero
    private var startX: CGFloat = 0
    private var distance: CGFloat = 1
    private var offset: CGFloat = 0
    private var isArmed = false
    private var didSearch = false
    private var dropX = Spring(0, stiffness: 26, dampingRatio: 0.62)
    private var dropRadius = Spring(0, stiffness: 20, dampingRatio: 0.45)
    private var socket = Spring(0, stiffness: 18, dampingRatio: 0.7)
    private var morph = Spring(0, stiffness: 13, dampingRatio: 0.85)

    func attach(to button: ChatAvatarButton) {
        self.button = button
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        press.minimumPressDuration = 0.25
        press.allowableMovement = .greatestFiniteMagnitude
        button.addGestureRecognizer(press)
        overlay.isUserInteractionEnabled = false
        canvas.gloss = 0.5
        canvas.rimWidth = 6
        canvas.onFrame = { [weak self] deltaTime in
            self?.step(deltaTime)
        }
        face.contentMode = .scaleAspectFill
        face.clipsToBounds = true
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        lens.image = UIImage(systemName: "magnifyingglass", withConfiguration: configuration)
        lens.tintColor = .white
        lens.sizeToFit()
        for view in [canvas, face, lens] {
            overlay.addSubview(view)
        }
    }

    @objc
    private func pressed(_ gesture: UILongPressGestureRecognizer) {
        let x = gesture.location(in: button?.window).x
        switch gesture.state {
        case .began:
            begin(at: x)
        case .changed:
            move(to: x)
        case .ended:
            release(search: isArmed)
        default:
            release(search: false)
        }
    }

    private func begin(at x: CGFloat) {
        guard phase == .idle, let button, let window = button.window else {
            return
        }

        let frame = button.convert(button.bounds, to: window)
        anchor = CGPoint(x: frame.midX, y: frame.midY)
        radius = frame.width / 2
        startX = x
        offset = 0
        distance = max(1, anchor.x - (window.safeAreaInsets.left + Self.backCenter))
        let left = window.safeAreaInsets.left + 16
        let right = window.bounds.width - window.safeAreaInsets.right - Self.fieldTrailing
        field = CGRect(x: left, y: anchor.y - Self.fieldHeight / 2, width: right - left, height: Self.fieldHeight)
        overlay.frame = window.bounds
        overlay.alpha = 1
        canvas.frame = CGRect(x: 0, y: 0, width: window.bounds.width, height: frame.maxY + 40)
        canvas.color = tint
        window.addSubview(overlay)
        face.image = button.contentImage()
        button.isContentHidden = true
        prepareSprings()
        phase = .dragging
        isArmed = false
        didSearch = false
        canvas.startFrames()
        Haptics.play(.tap)
    }

    private func prepareSprings() {
        let damping: CGFloat = UIAccessibility.isReduceMotionEnabled ? 1 : 0.45
        dropX.reset(to: anchor.x)
        dropRadius.reset(to: radius)
        dropRadius.dampingRatio = damping
        dropRadius.velocity = UIAccessibility.isReduceMotionEnabled ? 0 : 40
        socket.reset(to: radius + 4)
        morph.reset(to: 0)
    }

    private func move(to x: CGFloat) {
        guard phase == .dragging else {
            return
        }

        let raw = max(0, startX - x)
        offset = raw > distance ? distance + (raw - distance) * 0.2 : raw
        let armed = offset / distance >= Self.threshold
        guard armed != isArmed else {
            return
        }

        isArmed = armed
        Haptics.play(.threshold)
        if !UIAccessibility.isReduceMotionEnabled {
            dropRadius.velocity += armed ? 90 : -40
        }
    }

    private func release(search: Bool) {
        guard phase == .dragging else {
            return
        }

        phase = search ? .morphing : .returning
        if search {
            Haptics.play(.success)
        }
    }

    private func step(_ deltaTime: CFTimeInterval) {
        advance(deltaTime)
        draw()
        switch phase {
        case .returning where dropX.isSettled(at: anchor.x, tolerance: 0.5):
            finish()
        case .morphing where morph.value > 0.55 && !didSearch:
            didSearch = true
            onSearch?()
            UIView.animate(withDuration: 0.25, delay: 0.1) {
                self.overlay.alpha = 0
            }
        case .morphing where morph.isSettled(at: 1, tolerance: 0.01):
            finish()
        default:
            break
        }
    }

    private func advance(_ deltaTime: CFTimeInterval) {
        let progress = min(1, offset / distance)
        switch phase {
        case .idle:
            return
        case .dragging:
            dropX.step(toward: anchor.x - offset, deltaTime: deltaTime)
            dropRadius.step(toward: radius + (isArmed ? 3 : 0), deltaTime: deltaTime)
            let held = max(radius * 0.35, (radius + 4) * (1 - progress))
            socket.step(toward: isArmed ? 0 : held, deltaTime: deltaTime)
        case .returning:
            dropX.step(toward: anchor.x, deltaTime: deltaTime)
            dropRadius.step(toward: radius, deltaTime: deltaTime)
            socket.step(toward: radius + 4, deltaTime: deltaTime)
        case .morphing:
            morph.step(toward: 1, deltaTime: deltaTime)
            socket.step(toward: 0, deltaTime: deltaTime)
        }
    }

    private func draw() {
        let progress = max(0, min(1, (anchor.x - dropX.value) / distance))
        let value = max(0, dropRadius.value)
        let center = CGPoint(x: dropX.value, y: anchor.y)
        let circle = CGRect(x: center.x - value, y: center.y - value, width: value * 2, height: value * 2)
        let mix = max(0, min(1.05, morph.value))
        let shape = Self.mix(circle, field, mix)
        var blobs = [LiquidBlob(frame: shape, cornerRadius: shape.height / 2, blend: 0)]
        let held = max(0, socket.value)
        if held > 0.5 {
            let hole = CGRect(x: anchor.x - held, y: anchor.y - held, width: held * 2, height: held * 2)
            blobs.append(LiquidBlob(frame: hole, cornerRadius: held, blend: 10))
        }
        canvas.blobs = blobs
        let joined = phase != .morphing && !(phase == .dragging && isArmed) && held > 1
        canvas.bridges = joined && anchor.x - center.x > 4 ? [
            LiquidBridge(from: anchor, to: center, startRadius: held * 0.55, endRadius: value * 0.5, blend: 8),
        ] : []
        let side = max(0, value * 2 - 6)
        face.frame = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        face.layer.cornerRadius = side / 2
        face.alpha = (1 - min(1, mix)) * (1 - progress * 0.85)
        lens.center = CGPoint(x: shape.minX + shape.height / 2, y: shape.midY)
        lens.alpha = progress
    }

    private func finish() {
        phase = .idle
        canvas.stopFrames()
        canvas.blobs = []
        canvas.bridges = []
        canvas.render()
        overlay.removeFromSuperview()
        button?.isContentHidden = false
    }

    private static func mix(_ from: CGRect, _ to: CGRect, _ amount: CGFloat) -> CGRect {
        CGRect(
            x: from.minX + (to.minX - from.minX) * amount,
            y: from.minY + (to.minY - from.minY) * amount,
            width: from.width + (to.width - from.width) * amount,
            height: from.height + (to.height - from.height) * amount
        )
    }
}
