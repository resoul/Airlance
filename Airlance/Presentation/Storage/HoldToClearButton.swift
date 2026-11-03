import Haptics
import LiquidUI
import UIKit

final class HoldToClearButton: UIControl {
    private static let chargeTime: CFTimeInterval = 0.9

    var onFire: (@MainActor () -> Void)?

    private let fill = UIView()
    private let title = UILabel()
    private var charge: CGFloat = 0
    private var isHolding = false
    private var didFire = false
    private var sinceTick: CFTimeInterval = 0
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.step(deltaTime)
    }

    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1 : 0.4
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.cornerCurve = .continuous
        fill.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        fill.isUserInteractionEnabled = false
        title.textAlignment = .center
        title.isUserInteractionEnabled = false
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7
        addSubview(fill)
        addSubview(title)
        addTarget(self, action: #selector(pressDown), for: .touchDown)
        addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(title text: NSAttributedString, color: UIColor) {
        title.attributedText = text
        backgroundColor = color
        accessibilityLabel = text.string
    }

    override func accessibilityActivate() -> Bool {
        onFire?()

        return true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        title.frame = bounds.insetBy(dx: 16, dy: 0)
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * charge, height: bounds.height)
    }

    @objc
    private func pressDown() {
        isHolding = true
        didFire = false
        sinceTick = 0
        Haptics.play(.tap)
        driver.start()
    }

    @objc
    private func pressUp() {
        isHolding = false
    }

    private func step(_ deltaTime: CFTimeInterval) {
        let speed = CGFloat(deltaTime / Self.chargeTime)
        charge = isHolding ? min(1, charge + speed) : max(0, charge - speed * 2.5)
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * charge, height: bounds.height)
        let shake = isHolding ? CGFloat.random(in: -1...1) * charge * 1.5 : 0
        title.transform = CGAffineTransform(translationX: shake, y: 0)
        if isHolding {
            sinceTick += deltaTime
            if sinceTick > 0.16 - Double(charge) * 0.12 {
                sinceTick = 0
                Haptics.play(.selection)
            }
        }
        if isHolding, charge >= 1, !didFire {
            didFire = true
            isHolding = false
            charge = 0
            fill.frame.size.width = 0
            onFire?()
        }
        if !isHolding, charge <= 0 {
            title.transform = .identity
            driver.stop()
        }
    }
}
