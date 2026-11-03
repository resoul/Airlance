import Haptics
import LiquidUI
import UIKit

final class BoostStarButton: UIControl {
    static let chargeDuration: CFTimeInterval = 1.4

    var onBoost: (@MainActor (Bool) -> Void)?
    var onDenied: (@MainActor () -> Void)?
    var onCharge: (@MainActor (CGFloat) -> Void)?
    var canBoost = true
    var canSuperBoost = true
    var baseColor = UIColor.label

    private let layers = BoostStarLayers()
    private let lava = LiquidLavaView()
    private var progress: CGFloat = 0
    private var time: CGFloat = 0
    private var nextHaptic: CGFloat = 0
    private var isCharging = false
    private var didBurst = false
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.step(deltaTime)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(layers.track)
        layer.addSublayer(layers.ring)
        layer.addSublayer(layers.container)
        layer.addSublayer(layers.sparks)
        if LiquidLavaView.isSupported {
            lava.tint = UIColor(red: 1, green: 0.8, blue: 0.38, alpha: 1)
            lava.isAnimating = true
            insertSubview(lava, at: 0)
            layers.track.isHidden = true
            layers.ring.isHidden = true
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layers.layout(in: bounds)
        let side = min(bounds.width, bounds.height)
        lava.frame = bounds.insetBy(dx: -60, dy: -60)
        lava.innerRadius = side * 0.3
        lava.outerRadius = side * 0.52
        render()
        CATransaction.commit()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard canBoost else {
            deny()

            return
        }

        isCharging = true
        didBurst = false
        time = 0
        nextHaptic = 0
        Haptics.prepare(.charge(0.3))
        driver.start()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard isCharging else {
            return
        }

        isCharging = false
        if !didBurst {
            pop()
            onBoost?(false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isCharging = false
    }

    func refresh() {
        render()
    }

    private var maxCharge: CGFloat {
        canSuperBoost ? 1 : 0.7
    }

    private func step(_ deltaTime: CFTimeInterval) {
        time += CGFloat(deltaTime)
        if isCharging, !didBurst {
            progress = min(maxCharge, progress + CGFloat(deltaTime / Self.chargeDuration))
            hapticTick()
            if progress >= 1 {
                explode()
            }
        } else {
            progress = max(0, progress - CGFloat(deltaTime * 2.5))
            if progress == 0 {
                driver.stop()
            }
        }
        onCharge?(progress)
        render()
    }

    private func hapticTick() {
        guard time >= nextHaptic else {
            return
        }

        Haptics.play(.charge(0.25 + 0.75 * progress))
        nextHaptic = time + 0.2 - 0.16 * progress
    }

    private func render() {
        let heat = progress
        let shake = heat * heat
        let angle = sin(time * 55) * 0.06 * shake
        let offset = CGPoint(x: sin(time * 71) * 3 * shake, y: cos(time * 63) * 3 * shake)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layers.apply(heat: heat, base: baseColor)
        layers.ring.strokeEnd = heat
        layers.container.setAffineTransform(
            CGAffineTransform(translationX: offset.x, y: offset.y)
                .rotated(by: angle)
                .scaledBy(x: 1 + 0.32 * heat, y: 1 + 0.32 * heat)
        )
        layers.container.opacity = canBoost ? 1 : 0.4
        CATransaction.commit()
        lava.heat = heat
        lava.alpha = canBoost ? 1 : 0.4
    }

    private func explode() {
        didBurst = true
        Haptics.play(.burst)
        layers.burst()
        lava.burstOut()
        let flash = CABasicAnimation(keyPath: "transform.scale")
        flash.fromValue = 1.6
        flash.toValue = 1
        flash.duration = 0.45
        flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layers.container.add(flash, forKey: "flash")
        onBoost?(true)
    }

    private func pop() {
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1, 1.25, 0.94, 1]
        bounce.keyTimes = [0, 0.3, 0.7, 1]
        bounce.duration = 0.35
        layers.container.add(bounce, forKey: "pop")
        Haptics.play(.charge(1))
    }

    private func deny() {
        Haptics.play(.error)
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -10, 9, -6, 4, 0]
        shake.duration = 0.4
        layer.add(shake, forKey: "deny")
        onDenied?()
    }
}
