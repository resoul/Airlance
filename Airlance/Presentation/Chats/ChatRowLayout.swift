@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct ChatRowDraft: Sendable, Hashable {
    let title: String
    let color: UIColor
}

final class ChatRowLayout: ListPreparedLayout, @unchecked Sendable {
    static let avatarSize: CGFloat = 56
    static let avatarX: CGFloat = 12
    static let textX: CGFloat = avatarX + avatarSize + 12
    static let rightInset: CGFloat = 14

    let content: ListRowContent

    init(
        chat: ChatSummary,
        timeText: String,
        width: CGFloat,
        theme: ListTheme,
        grayBadge: Bool = false,
        draft: ChatRowDraft? = nil
    ) {
        let height = Self.height(theme: theme)
        var content = ListRowContent(size: CGSize(width: width, height: height))
        let draftText = draft == nil ? nil : chat.draft
        var topChat = chat
        if draftText != nil {
            topChat.outgoingRead = nil
        }
        let nameBottom = Self.addTopLine(to: &content, chat: topChat, timeText: timeText, width: width, theme: theme)
        let messageRight = Self.addTrailing(
            to: &content,
            chat: chat,
            grayBadge: grayBadge,
            width: width,
            height: height,
            theme: theme
        )
        let message = NSMutableAttributedString(
            string: draftText ?? chat.message,
            attributes: [.font: theme.subtitleFont, .foregroundColor: theme.secondary]
        )
        if let draft, draftText != nil {
            let title = NSAttributedString(
                string: draft.title + ": ",
                attributes: [.font: theme.subtitleFont, .foregroundColor: draft.color]
            )
            message.insert(title, at: 0)
        }
        let messageWidth = max(1, messageRight - Self.textX)
        let messageSize = ListRowContent.measure(message, width: messageWidth, lines: 2)
        let messageFrame = CGRect(origin: CGPoint(x: Self.textX, y: nameBottom + 3), size: messageSize)
        content.elements.append(.text(message, lines: 2, frame: messageFrame))
        self.content = content
    }

    private static func addTopLine(
        to content: inout ListRowContent,
        chat: ChatSummary,
        timeText: String,
        width: CGFloat,
        theme: ListTheme
    ) -> CGFloat {
        let timeSize = measure(timeText, font: theme.subtitleFont, width: width / 3, lines: 1)
        let timeOrigin = CGPoint(x: width - rightInset - timeSize.width, y: 10)
        let font = theme.subtitleFont
        let time = text(timeText, font: font, color: theme.secondary, width: width / 3, lines: 1, origin: timeOrigin)
        content.elements.append(time.element)

        var titleRight = time.frame.minX - 6
        if let read = chat.outgoingRead {
            let frame = CGRect(x: titleRight - 16, y: 10, width: 16, height: timeSize.height)
            let symbol = read ? "checkmark.circle.fill" : "checkmark"
            content.elements.append(icon(symbol, size: 12, color: theme.accent, frame: frame))
            titleRight = frame.minX - 4
        }

        let muteWidth: CGFloat = chat.isMuted ? 18 : 0
        let name = text(
            chat.name,
            font: boldFont(theme.titleFont),
            color: theme.primary,
            width: max(1, titleRight - textX - muteWidth),
            lines: 1,
            origin: CGPoint(x: textX, y: 8)
        )
        content.elements.append(name.element)
        if chat.isMuted {
            let frame = CGRect(x: name.frame.maxX + 4, y: name.frame.minY, width: 14, height: name.frame.height)
            content.elements.append(icon("speaker.slash.fill", size: 11, color: theme.secondary, frame: frame))
        }

        return name.frame.maxY
    }

    private static func addTrailing(
        to content: inout ListRowContent,
        chat: ChatSummary,
        grayBadge: Bool,
        width: CGFloat,
        height: CGFloat,
        theme: ListTheme
    ) -> CGFloat {
        if chat.unread > 0 {
            let badge = badge(chat.unread, muted: chat.isMuted || grayBadge, theme: theme)
            let origin = CGPoint(x: width - rightInset - badge.size.width, y: height - 12 - badge.size.height)
            content.elements += badge.elements(at: origin)

            return origin.x - 8
        }

        if chat.isPinned {
            let frame = CGRect(x: width - rightInset - 18, y: height - 34, width: 18, height: 22)
            content.elements.append(icon("pin.fill", size: 13, color: theme.secondary, frame: frame))

            return frame.minX - 8
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
        lines: UInt,
        origin: CGPoint
    ) -> (element: ListRowElement, frame: CGRect) {
        let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let size = ListRowContent.measure(attributed, width: width, lines: lines)
        let frame = CGRect(origin: origin, size: size)

        return (.text(attributed, lines: lines, frame: frame), frame)
    }

    private static func measure(_ string: String, font: UIFont, width: CGFloat, lines: UInt) -> CGSize {
        let attributed = NSAttributedString(string: string, attributes: [.font: font])

        return ListRowContent.measure(attributed, width: width, lines: lines)
    }

    private static func icon(_ symbol: String, size: CGFloat, color: UIColor, frame: CGRect) -> ListRowElement {
        .image(ListRowSymbols.image(symbol, size: size, color: color), frame: frame)
    }

    private static func badge(_ count: Int, muted: Bool, theme: ListTheme) -> ChatRowBadge {
        let font = theme.subtitleFont
        let number = NSAttributedString(
            string: count > 999 ? "999+" : "\(count)",
            attributes: [.font: font, .foregroundColor: UIColor.white]
        )
        let numberSize = ListRowContent.measure(number, width: 80, lines: 1)
        let height = max(22, ceil(font.lineHeight) + 4)
        let width = max(height, numberSize.width + 14)

        return ChatRowBadge(
            size: CGSize(width: width, height: height),
            color: muted ? theme.secondary : theme.accent,
            number: number,
            numberSize: numberSize
        )
    }

    private static func boldFont(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return font
        }

        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}

private struct ChatRowBadge {
    let size: CGSize
    let color: UIColor
    let number: NSAttributedString
    let numberSize: CGSize

    func elements(at origin: CGPoint) -> [ListRowElement] {
        let numberOrigin = CGPoint(
            x: origin.x + (size.width - numberSize.width) / 2,
            y: origin.y + (size.height - numberSize.height) / 2
        )

        return [
            .box(color, cornerRadius: size.height / 2, frame: CGRect(origin: origin, size: size)),
            .text(number, lines: 1, frame: CGRect(origin: numberOrigin, size: numberSize)),
        ]
    }
}
