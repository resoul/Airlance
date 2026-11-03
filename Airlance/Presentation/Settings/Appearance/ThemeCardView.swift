import Theme
import UIKit

struct ThemeCardModel {
    let wallpaper: ThemeWallpaper?
    let background: UIColor
    let outgoing: [UIColor]
    let incoming: UIColor
    var emoji: String?
    var caption: String?
}

final class ThemeCardView: UIControl {
    static let captionHeight: CGFloat = 24

    private let card = UIView()
    private let wallpaper = ChatWallpaperView()
    private let incoming = UIView()
    private let outgoing = UIView()
    private let gradient = CAGradientLayer()
    private let emoji = UILabel()
    private let caption = UILabel()
    private var hasCaption = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.clipsToBounds = true
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.isUserInteractionEnabled = false
        card.addSubview(wallpaper)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        outgoing.layer.addSublayer(gradient)
        outgoing.clipsToBounds = true
        for view in [incoming, outgoing, emoji] {
            card.addSubview(view)
        }
        emoji.textAlignment = .center
        caption.textAlignment = .center
        caption.isUserInteractionEnabled = false
        addSubview(card)
        addSubview(caption)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ model: ThemeCardModel, selected: Bool, theme: AppTheme) {
        card.backgroundColor = model.background
        wallpaper.apply(model.wallpaper)
        incoming.backgroundColor = model.incoming
        gradient.colors = (model.outgoing.count > 1 ? model.outgoing : model.outgoing + model.outgoing).map(\.cgColor)
        emoji.text = model.emoji
        hasCaption = model.caption != nil
        caption.text = model.caption
        caption.font = theme.fonts.caption
        caption.textColor = selected ? theme.colors.accent : theme.colors.textPrimary
        card.layer.borderWidth = selected ? 2.5 : 0
        card.layer.borderColor = theme.colors.accent.cgColor
        accessibilityLabel = model.caption ?? model.emoji
        accessibilityTraits = selected ? [.button, .selected] : .button
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cardHeight = bounds.height - (hasCaption ? Self.captionHeight : 0)
        card.frame = CGRect(x: 0, y: 0, width: bounds.width, height: cardHeight)
        caption.frame = CGRect(x: 0, y: cardHeight, width: bounds.width, height: Self.captionHeight)
        wallpaper.frame = card.bounds
        let width = card.bounds.width
        let bubble = max(14, cardHeight * 0.16)
        outgoing.frame = CGRect(x: width * 0.36, y: cardHeight * 0.16, width: width * 0.52, height: bubble)
        incoming.frame = CGRect(x: width * 0.12, y: outgoing.frame.maxY + 8, width: width * 0.48, height: bubble)
        for view in [outgoing, incoming] {
            view.layer.cornerRadius = bubble / 2
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = outgoing.bounds
        CATransaction.commit()
        emoji.font = .systemFont(ofSize: min(34, cardHeight * 0.24))
        let emojiTop = incoming.frame.maxY + 4
        emoji.frame = CGRect(x: 0, y: emojiTop, width: width, height: cardHeight - emojiTop - 4)
    }
}

extension ThemeCardModel {
    static func preset(_ preset: ChatThemePreset, theme: AppTheme) -> ThemeCardModel {
        let appearance = theme.appearance

        return ThemeCardModel(
            wallpaper: preset.wallpaper.resolved(for: appearance),
            background: theme.colors.background,
            outgoing: preset.accent.bubbleColors(for: appearance),
            incoming: theme.colors.surface,
            emoji: preset.emoji
        )
    }

    static func night(_ style: NightStyle, theme: AppTheme, caption: String) -> ThemeCardModel {
        ThemeCardModel(
            wallpaper: theme.chatAppearance.wallpaper.resolved(for: .dark, color: theme.chatAppearance.wallpaperColor),
            background: style.background,
            outgoing: theme.accent.bubbleColors(for: .dark),
            incoming: style.surface,
            caption: caption
        )
    }
}
