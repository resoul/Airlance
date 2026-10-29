@preconcurrency import AsyncDisplayKit
import AvatarUI
import Theme
import UIKit

final class ChatTitleView: UIControl {
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()

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
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: CGSize {
        let width = max(nameLabel.intrinsicContentSize.width, statusLabel.intrinsicContentSize.width)
        let status = statusLabel.text == nil ? 0 : ceil(statusLabel.font.lineHeight)

        return CGSize(width: min(width, 240), height: ceil(nameLabel.font.lineHeight) + status)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }

    func apply(name: String, status: String?, isOnline: Bool, theme: AppTheme) {
        nameLabel.text = name
        nameLabel.font = theme.fonts.headline
        nameLabel.textColor = theme.colors.textPrimary
        statusLabel.text = status
        statusLabel.font = theme.fonts.caption
        statusLabel.textColor = isOnline ? theme.colors.accent : theme.colors.textSecondary
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
