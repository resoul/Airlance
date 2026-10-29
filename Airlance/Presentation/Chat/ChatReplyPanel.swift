import Theme
import UIKit

struct ChatPanelContent {
    let symbol: String
    let title: String
    let text: String
    let closeLabel: String
}

final class ChatReplyPanel: UIView {
    static let height: CGFloat = 46

    var onClose: (@MainActor () -> Void)?

    private let icon = UIImageView()
    private let bar = UIView()
    private let title = UILabel()
    private let text = UILabel()
    private let close = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        icon.contentMode = .center
        bar.layer.cornerRadius = 1.5
        let closeImage = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15))
        close.setImage(closeImage, for: .normal)
        close.addAction(
            UIAction { [weak self] _ in
                self?.onClose?()
            },
            for: .touchUpInside
        )
        for view in [icon, bar, title, text, close] {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme) {
        icon.tintColor = theme.colors.accent
        bar.backgroundColor = theme.colors.accent
        title.font = HistoryStyle(theme: theme).nameFont
        title.textColor = theme.colors.accent
        text.font = theme.fonts.subheadline
        text.textColor = theme.colors.textPrimary
        close.tintColor = theme.colors.textSecondary
    }

    func show(_ content: ChatPanelContent) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        icon.image = UIImage(systemName: content.symbol, withConfiguration: configuration)
        title.text = content.title
        text.text = content.text.replacingOccurrences(of: "\n", with: " ")
        close.accessibilityLabel = content.closeLabel
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = Self.height
        let width = bounds.width
        icon.frame = CGRect(x: 6, y: 0, width: 40, height: height)
        bar.frame = CGRect(x: 50, y: 8, width: 3, height: height - 16)
        let titleHeight = ceil(title.font?.lineHeight ?? 17)
        let textHeight = ceil(text.font?.lineHeight ?? 17)
        let top = (height - titleHeight - textHeight) / 2
        title.frame = CGRect(x: 60, y: top, width: width - 110, height: titleHeight)
        text.frame = CGRect(x: 60, y: top + titleHeight, width: width - 110, height: textHeight)
        close.frame = CGRect(x: width - 46, y: 1, width: 44, height: 44)
    }
}
