import Haptics
import Theme
import UIKit

final class ChatScrollDownButton: UIControl {
    static let size: CGFloat = 40

    private let icon = UIImageView()
    private let badge = UILabel()
    private(set) var isShown = false

    override var isHighlighted: Bool {
        didSet {
            alpha = isShown ? (isHighlighted ? 0.6 : 1) : 0
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = Self.size / 2
        layer.borderWidth = 0.5
        icon.contentMode = .center
        icon.image = UIImage(
            systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        )
        icon.isUserInteractionEnabled = false
        addSubview(icon)
        badge.textAlignment = .center
        badge.clipsToBounds = true
        badge.isHidden = true
        addSubview(badge)
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        let colors = presentation.theme.colors
        backgroundColor = colors.surface
        layer.borderColor = colors.separator.cgColor
        icon.tintColor = colors.textSecondary
        badge.backgroundColor = colors.accent
        badge.textColor = colors.onAccent
        badge.font = presentation.theme.fonts.caption
        accessibilityLabel = presentation.strings.chatScrollDown
    }

    func update(isShown: Bool, unseen: Int) {
        badge.text = unseen > 99 ? "99+" : "\(unseen)"
        badge.isHidden = unseen == 0
        setNeedsLayout()
        guard isShown != self.isShown else {
            return
        }

        self.isShown = isShown
        isUserInteractionEnabled = isShown
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
            self.alpha = isShown ? 1 : 0
            self.transform = isShown ? .identity : CGAffineTransform(scaleX: 0.6, y: 0.6)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        icon.frame = bounds
        let height = ceil(badge.font.lineHeight) + 4
        let width = max(height, ceil(badge.intrinsicContentSize.width) + 10)
        badge.frame = CGRect(x: (bounds.width - width) / 2, y: -height / 2 - 2, width: width, height: height)
        badge.layer.cornerRadius = height / 2
    }

    override func sendActions(for controlEvents: UIControl.Event) {
        if controlEvents.contains(.touchUpInside) {
            Haptics.play(.tap)
        }
        super.sendActions(for: controlEvents)
    }
}
