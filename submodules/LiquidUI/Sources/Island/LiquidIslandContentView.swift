import UIKit

public struct LiquidIslandContent {
    public let title: String
    public let message: String
    public let leading: UIView?
    public let replyPlaceholder: String?
    public let titleFont: UIFont
    public let messageFont: UIFont

    public init(
        title: String,
        message: String,
        leading: UIView? = nil,
        replyPlaceholder: String? = nil,
        titleFont: UIFont = .systemFont(ofSize: 15, weight: .semibold),
        messageFont: UIFont = .systemFont(ofSize: 13)
    ) {
        self.title = title
        self.message = message
        self.leading = leading
        self.replyPlaceholder = replyPlaceholder
        self.titleFont = titleFont
        self.messageFont = messageFont
    }
}

final class LiquidIslandContentView: UIView {
    static let compactHeight: CGFloat = 64
    static let expandedHeight: CGFloat = 120

    let replyField = UITextField()

    private let leading: UIView?
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()

    init(_ content: LiquidIslandContent) {
        leading = content.leading
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        if let leading {
            leading.isUserInteractionEnabled = false
            addSubview(leading)
        }
        titleLabel.text = content.title
        titleLabel.font = content.titleFont
        titleLabel.textColor = .white
        addSubview(titleLabel)
        messageLabel.text = content.message.replacingOccurrences(of: "\n", with: " ")
        messageLabel.font = content.messageFont
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        addSubview(messageLabel)
        setupField(placeholder: content.replyPlaceholder ?? "", font: content.messageFont)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rowHeight = Self.compactHeight
        let leadingSize: CGFloat = leading == nil ? 0 : 38
        leading?.frame = CGRect(x: 18, y: (rowHeight - leadingSize) / 2, width: leadingSize, height: leadingSize)
        let textX: CGFloat = leading == nil ? 24 : 18 + leadingSize + 12
        let textWidth = max(0, bounds.width - textX - 20)
        let titleHeight = ceil(titleLabel.font.lineHeight)
        let messageHeight = ceil(messageLabel.font.lineHeight)
        let top = (rowHeight - titleHeight - messageHeight - 1) / 2
        titleLabel.frame = CGRect(x: textX, y: top, width: textWidth, height: titleHeight)
        messageLabel.frame = CGRect(x: textX, y: titleLabel.frame.maxY + 1, width: textWidth, height: messageHeight)
        replyField.frame = CGRect(x: 16, y: rowHeight - 4, width: bounds.width - 32, height: 38)
    }

    func showField() {
        replyField.isHidden = false
        replyField.alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0.08) {
            self.replyField.alpha = 1
        }
        replyField.becomeFirstResponder()
    }

    private func setupField(placeholder: String, font: UIFont) {
        replyField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.45)]
        )
        replyField.textColor = .white
        replyField.tintColor = .white
        replyField.font = font.withSize(15)
        replyField.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        replyField.layer.cornerRadius = 19
        replyField.layer.cornerCurve = .continuous
        replyField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        replyField.leftViewMode = .always
        replyField.returnKeyType = .send
        replyField.enablesReturnKeyAutomatically = true
        replyField.keyboardAppearance = .dark
        replyField.isHidden = true
        addSubview(replyField)
    }
}
