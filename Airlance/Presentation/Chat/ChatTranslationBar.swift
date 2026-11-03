import Theme
import UIKit

final class ChatTranslationBar: UIControl {
    static let height: CGFloat = 40
    static let chipHeight: CGFloat = 34

    var isChip = false {
        didSet {
            setNeedsLayout()
        }
    }

    var onClose: (@MainActor () -> Void)?

    private let icon = UIImageView()
    private let label = UILabel()
    private let close = UIButton(type: .system)
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.image = UIImage(systemName: "translate", withConfiguration: configuration)
        icon.contentMode = .center
        label.textAlignment = .center
        close.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        close.addAction(
            UIAction { [weak self] _ in
                self?.onClose?()
            },
            for: .touchUpInside
        )
        for view in [icon, label, separator] {
            view.isUserInteractionEnabled = false
            addSubview(view)
        }
        addSubview(close)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme, closeLabel: String) {
        backgroundColor = theme.colors.background
        separator.backgroundColor = theme.colors.separator
        icon.tintColor = theme.colors.accent
        label.font = theme.fonts.subheadline
        label.textColor = theme.colors.accent
        close.tintColor = theme.colors.textSecondary
        close.accessibilityLabel = closeLabel
    }

    func setTitle(_ title: String) {
        label.text = title
        accessibilityLabel = title
        setNeedsLayout()
    }

    func chipWidth(maxWidth: CGFloat) -> CGFloat {
        min(maxWidth, ceil(label.intrinsicContentSize.width) + 12 + 20 + 6 + 36)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        separator.isHidden = isChip
        guard !isChip else {
            layoutChip()

            return
        }

        let width = min(ceil(label.intrinsicContentSize.width), bounds.width - 120)
        let total = width + 26
        let x = (bounds.width - total) / 2
        icon.frame = CGRect(x: x, y: 0, width: 20, height: bounds.height)
        label.frame = CGRect(x: x + 26, y: 0, width: width, height: bounds.height)
        close.frame = CGRect(x: bounds.width - 44, y: 0, width: 44, height: bounds.height)
        let line = 1 / max(traitCollection.displayScale, 1)
        separator.frame = CGRect(x: 0, y: bounds.height - line, width: bounds.width, height: line)
    }

    private func layoutChip() {
        icon.frame = CGRect(x: 12, y: 0, width: 20, height: bounds.height)
        close.frame = CGRect(x: bounds.width - 36, y: 0, width: 36, height: bounds.height)
        let labelX = icon.frame.maxX + 6
        label.frame = CGRect(x: labelX, y: 0, width: max(1, close.frame.minX - labelX), height: bounds.height)
    }
}
