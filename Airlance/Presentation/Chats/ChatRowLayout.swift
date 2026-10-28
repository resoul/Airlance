@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

final class ChatRowLayout: ListPreparedLayout, @unchecked Sendable {
    static let avatarSize: CGFloat = 56
    static let avatarX: CGFloat = 12
    static let textX: CGFloat = avatarX + avatarSize + 12
    static let rightInset: CGFloat = 14

    let content: ASDisplayNode

    init(chat: ChatSummary, timeText: String, width: CGFloat, theme: ListTheme) {
        let height = Self.height(theme: theme)
        let content = ASDisplayNode()
        content.isLayerBacked = true
        content.frame = CGRect(x: 0, y: 0, width: width, height: height)

        let nameBottom = Self.addTopLine(to: content, chat: chat, timeText: timeText, width: width, theme: theme)
        let messageRight = Self.addTrailing(to: content, chat: chat, width: width, height: height, theme: theme)
        let message = Self.text(
            chat.message,
            font: theme.subtitleFont,
            color: theme.secondary,
            width: max(1, messageRight - Self.textX),
            lines: 2
        )
        message.frame.origin = CGPoint(x: Self.textX, y: nameBottom + 3)
        content.addSubnode(message)

        self.content = content
    }

    private static func addTopLine(
        to content: ASDisplayNode,
        chat: ChatSummary,
        timeText: String,
        width: CGFloat,
        theme: ListTheme
    ) -> CGFloat {
        let time = text(timeText, font: theme.subtitleFont, color: theme.secondary, width: width / 3, lines: 1)
        time.frame.origin = CGPoint(x: width - rightInset - time.frame.width, y: 10)
        content.addSubnode(time)

        var titleRight = time.frame.minX - 6
        if let read = chat.outgoingRead {
            let checks = icon(read ? "checkmark.circle.fill" : "checkmark", size: 12, color: theme.accent)
            checks.frame = CGRect(x: titleRight - 16, y: 10, width: 16, height: time.frame.height)
            content.addSubnode(checks)
            titleRight = checks.frame.minX - 4
        }

        let muteWidth: CGFloat = chat.isMuted ? 18 : 0
        let name = text(
            chat.name,
            font: boldFont(theme.titleFont),
            color: theme.primary,
            width: max(1, titleRight - textX - muteWidth),
            lines: 1
        )
        name.frame.origin = CGPoint(x: textX, y: 8)
        content.addSubnode(name)
        if chat.isMuted {
            let mute = icon("speaker.slash.fill", size: 11, color: theme.secondary)
            mute.frame = CGRect(x: name.frame.maxX + 4, y: name.frame.minY, width: 14, height: name.frame.height)
            content.addSubnode(mute)
        }

        return name.frame.maxY
    }

    private static func addTrailing(
        to content: ASDisplayNode,
        chat: ChatSummary,
        width: CGFloat,
        height: CGFloat,
        theme: ListTheme
    ) -> CGFloat {
        if chat.unread > 0 {
            let badge = badge(chat.unread, muted: chat.isMuted, theme: theme)
            let size = badge.frame.size
            badge.frame.origin = CGPoint(x: width - rightInset - size.width, y: height - 12 - size.height)
            content.addSubnode(badge)

            return badge.frame.minX - 8
        }

        if chat.isPinned {
            let pin = icon("pin.fill", size: 13, color: theme.secondary)
            pin.frame = CGRect(x: width - rightInset - 18, y: height - 34, width: 18, height: 22)
            content.addSubnode(pin)

            return pin.frame.minX - 8
        }

        return width - rightInset
    }

    static func height(theme: ListTheme) -> CGFloat {
        max(76, (8 + theme.titleFont.lineHeight + 3 + theme.subtitleFont.lineHeight * 2 + 10).rounded(.up))
    }

    private static func text(
        _ string: String,
        font: UIFont,
        color: UIColor,
        width: CGFloat,
        lines: UInt
    ) -> ASTextNode {
        let node = ASTextNode()
        node.isLayerBacked = true
        node.maximumNumberOfLines = lines
        node.truncationMode = .byTruncatingTail
        node.attributedText = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let range = ASSizeRange(min: .zero, max: CGSize(width: width, height: .greatestFiniteMagnitude))
        node.frame = CGRect(origin: .zero, size: node.layoutThatFits(range).size)

        return node
    }

    private static func icon(_ symbol: String, size: CGFloat, color: UIColor) -> ASImageNode {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.contentMode = .center
        node.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: size))?
            .withTintColor(color, renderingMode: .alwaysOriginal)

        return node
    }

    private static func badge(_ count: Int, muted: Bool, theme: ListTheme) -> ASDisplayNode {
        let font = theme.subtitleFont
        let number = text(count > 999 ? "999+" : "\(count)", font: font, color: .white, width: 80, lines: 1)
        let height = max(22, ceil(font.lineHeight) + 4)
        let width = max(height, number.frame.width + 14)

        let badge = ASDisplayNode()
        badge.isLayerBacked = true
        badge.frame = CGRect(x: 0, y: 0, width: width, height: height)
        badge.backgroundColor = muted ? theme.secondary : theme.accent
        badge.cornerRadius = height / 2
        number.frame.origin = CGPoint(x: (width - number.frame.width) / 2, y: (height - number.frame.height) / 2)
        badge.addSubnode(number)

        return badge
    }

    private static func boldFont(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return font
        }

        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
