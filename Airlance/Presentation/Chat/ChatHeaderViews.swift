@preconcurrency import AsyncDisplayKit
import AvatarUI
import Theme
import UIKit

final class ChatTitleView: UIControl {
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let dots = TypingDotsView()

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.6 : 1
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        nameLabel.textAlignment = .center
        statusLabel.textAlignment = .center
        addSubview(nameLabel)
        addSubview(statusLabel)
        addSubview(dots)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: CGSize {
        let dotsWidth = dots.isAnimating ? (TypingDotsView.width + 2) * 2 : 0
        let width = max(nameLabel.intrinsicContentSize.width, statusLabel.intrinsicContentSize.width + dotsWidth)
        let status = statusLabel.text == nil ? 0 : ceil(statusLabel.font.lineHeight)

        return CGSize(width: min(width, 240), height: ceil(nameLabel.font.lineHeight) + status)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }

    func apply(name: String, status: String?, isOnline: Bool, isTyping: Bool = false, theme: AppTheme) {
        nameLabel.text = name
        nameLabel.font = theme.fonts.headline
        nameLabel.textColor = theme.colors.textPrimary
        statusLabel.text = status
        statusLabel.font = theme.fonts.caption
        statusLabel.textColor = isOnline || isTyping ? theme.colors.accent : theme.colors.textSecondary
        dots.color = theme.colors.accent
        dots.isAnimating = isTyping
        accessibilityLabel = [name, status].compactMap(\.self).joined(separator: ", ")
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let nameHeight = ceil(nameLabel.font.lineHeight)
        let statusHeight = statusLabel.text == nil ? 0 : ceil(statusLabel.font.lineHeight)
        let top = (bounds.height - nameHeight - statusHeight) / 2
        nameLabel.frame = CGRect(x: 0, y: top, width: bounds.width, height: nameHeight)
        statusLabel.frame = CGRect(x: 0, y: top + nameHeight, width: bounds.width, height: statusHeight)
        let textWidth = min(bounds.width, statusLabel.intrinsicContentSize.width)
        dots.frame = CGRect(
            x: min(bounds.width - TypingDotsView.width, (bounds.width + textWidth) / 2 + 2),
            y: statusLabel.frame.midY - 2,
            width: TypingDotsView.width,
            height: 6
        )
    }
}

final class TypingDotsView: UIView {
    static let width: CGFloat = 16

    var color: UIColor = .systemBlue {
        didSet {
            for dot in dotLayers {
                dot.backgroundColor = color.cgColor
            }
        }
    }

    var isAnimating = false {
        didSet {
            guard isAnimating != oldValue else {
                return
            }

            isHidden = !isAnimating
            isAnimating ? start() : stop()
        }
    }

    private let dotLayers = (0..<3).map { _ in
        CALayer()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        isUserInteractionEnabled = false
        for dot in dotLayers {
            dot.cornerRadius = 1.5
            layer.addSublayer(dot)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, dot) in dotLayers.enumerated() {
            dot.frame = CGRect(x: CGFloat(index) * 5, y: bounds.midY - 1.5, width: 3, height: 3)
        }
    }

    private func start() {
        for (index, dot) in dotLayers.enumerated() {
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = [0.25, 1, 0.25]
            animation.keyTimes = [0, 0.5, 1]
            animation.duration = 1.0
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.18
            animation.repeatCount = .infinity
            dot.add(animation, forKey: "typing")
        }
    }

    private func stop() {
        for dot in dotLayers {
            dot.removeAnimation(forKey: "typing")
        }
    }
}

final class ChatAvatarButton: UIControl {
    static let size: CGFloat = 36

    private let avatar = AvatarNode()

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.6 : 1
        }
    }

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
        avatar.isUserInteractionEnabled = false
        addSubview(avatar.view)
        isAccessibilityElement = true
        accessibilityTraits = .button
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size),
            heightAnchor.constraint(equalToConstant: Self.size),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ descriptor: AvatarDescriptor, label: String) {
        avatar.apply(descriptor, presentation: .list)
        accessibilityLabel = label
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatar.frame = bounds
    }
}
