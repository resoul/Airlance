import ChatHistory
import Theme
import UIKit

struct ChatPreviewModel {
    let incoming: String
    let outgoing: String
    let font: UIFont
    let radius: CGFloat
    let outgoingColors: [UIColor]
    let incomingColor: UIColor
    let incomingText: UIColor
    let outgoingText: UIColor
    let background: UIColor
    let wallpaper: ThemeWallpaper?
}

final class ChatAppearancePreview: UIView {
    private let wallpaper = ChatWallpaperView()
    private let incoming = PreviewBubble(outgoing: false)
    private let outgoing = PreviewBubble(outgoing: true)

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        clipsToBounds = true
        addSubview(wallpaper)
        addSubview(incoming)
        addSubview(outgoing)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ model: ChatPreviewModel) {
        backgroundColor = model.background
        wallpaper.apply(model.wallpaper)
        incoming.apply(model.incoming, font: model.font, radius: model.radius, colors: [model.incomingColor])
        incoming.label.textColor = model.incomingText
        outgoing.apply(model.outgoing, font: model.font, radius: model.radius, colors: model.outgoingColors)
        outgoing.label.textColor = model.outgoingText
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        wallpaper.frame = bounds
        let maxWidth = bounds.width * 0.75
        let inset: CGFloat = 16
        let incomingSize = incoming.size(maxWidth: maxWidth)
        incoming.frame = CGRect(origin: CGPoint(x: inset, y: 24), size: incomingSize)
        let outgoingSize = outgoing.size(maxWidth: maxWidth)
        outgoing.frame = CGRect(
            origin: CGPoint(x: bounds.width - inset - outgoingSize.width, y: incoming.frame.maxY + 12),
            size: outgoingSize
        )
    }
}

private final class PreviewBubble: UIView {
    private static let padding = UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)

    let label = UILabel()
    private let isOutgoing: Bool
    private let shape = CAShapeLayer()
    private let gradient = CAGradientLayer()
    private let gradientMask = CAShapeLayer()
    private var radius: CGFloat = 17

    init(outgoing: Bool) {
        isOutgoing = outgoing
        super.init(frame: .zero)
        label.numberOfLines = 0
        gradient.mask = gradientMask
        layer.addSublayer(shape)
        layer.addSublayer(gradient)
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ text: String, font: UIFont, radius: CGFloat, colors: [UIColor]) {
        label.text = text
        label.font = font
        self.radius = radius
        shape.fillColor = colors.first?.cgColor
        gradient.isHidden = colors.count < 2
        gradient.colors = colors.map(\.cgColor)
        setNeedsLayout()
    }

    func size(maxWidth: CGFloat) -> CGSize {
        let padding = Self.padding
        let width = maxWidth - padding.left - padding.right
        let fit = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))

        return CGSize(
            width: ceil(fit.width + padding.left + padding.right),
            height: ceil(fit.height + padding.top + padding.bottom)
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.inset(by: Self.padding)
        let grouping = HistoryGrouping()
        let path = BubblePath.make(size: bounds.size, outgoing: isOutgoing, grouping: grouping, radius: radius)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = path
        gradient.frame = bounds.insetBy(dx: -MessageBubbleLayout.tailWidth, dy: 0)
        var transform = CGAffineTransform(translationX: MessageBubbleLayout.tailWidth, y: 0)
        gradientMask.path = path.copy(using: &transform)
        CATransaction.commit()
    }
}
