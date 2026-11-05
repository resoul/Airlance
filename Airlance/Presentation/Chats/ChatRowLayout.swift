@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct ChatRowDraft: Sendable, Hashable {
    let title: String
    let color: UIColor
}

struct ChatRowTag: Sendable, Hashable {
    let title: String
    let color: UIColor
}

final class ChatRowLayout: ListPreparedLayout, @unchecked Sendable {
    static let avatarSize: CGFloat = 56
    static let avatarX: CGFloat = 12
    static let textX: CGFloat = avatarX + avatarSize + 12
    static let rightInset: CGFloat = 14
    static let thumbnailSide: CGFloat = 20
    static let thumbnailRadius: CGFloat = 4
    private static let cutoutGap: CGFloat = 4
    private static let markSide: CGFloat = 12

    let content: ListRowContent
    let thumbnails: [ChatRowThumbnail]
    let thumbnailFrames: [CGRect]
    let typingOrigin: CGPoint?
    let typingColor: UIColor

    init(
        chat: ChatSummary,
        timeText: String,
        width: CGFloat,
        theme: ListTheme,
        grayBadge: Bool = false,
        draft: ChatRowDraft? = nil,
        typing: String? = nil,
        messageText: String? = nil,
        tags: [ChatRowTag] = []
    ) {
        let height = Self.height(theme: theme)
        var content = ListRowContent(size: CGSize(width: width, height: height))
        let draftText = draft == nil || typing != nil ? nil : chat.draft
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
        let message = Self.message(
            typing ?? draftText ?? messageText ?? chat.message,
            draft: draftText == nil ? nil : draft,
            isTyping: typing != nil,
            theme: theme
        )
        let isPlain = typing != nil || draftText != nil
        let messageY = nameBottom + 3
        let marks = isPlain ? .none : Self.addMarks(to: &content, chat: chat, y: messageY, theme: theme)
        thumbnails = marks.thumbnails
        thumbnailFrames = marks.frames
        Self.indent(message, by: marks.cutout)
        let messageWidth = max(1, messageRight - Self.textX)
        let messageFrame = Self.addMessage(
            message,
            tags: tags,
            to: &content,
            origin: CGPoint(x: Self.textX, y: messageY),
            width: messageWidth
        )
        Self.addTags(tags, to: &content, y: messageFrame.maxY + 3, right: messageRight, theme: theme)
        typingColor = theme.accent
        typingOrigin = typing == nil ? nil : Self.typingOrigin(after: messageFrame, right: messageRight)
        self.content = content
    }

    private static func typingOrigin(after frame: CGRect, right: CGFloat) -> CGPoint {
        CGPoint(x: min(frame.maxX + 3, right - ChatRowTypingNode.width), y: frame.minY + (frame.height - 4) / 2 + 3)
    }

    private static func message(
        _ text: String,
        draft: ChatRowDraft?,
        isTyping: Bool,
        theme: ListTheme
    ) -> NSMutableAttributedString {
        let message = NSMutableAttributedString(
            string: text,
            attributes: [.font: theme.subtitleFont, .foregroundColor: isTyping ? theme.accent : theme.secondary]
        )
        if let draft {
            let title = NSAttributedString(
                string: draft.title + ": ",
                attributes: [.font: theme.subtitleFont, .foregroundColor: draft.color]
            )
            message.insert(title, at: 0)
        }

        return message
    }

    private struct Marks {
        static let none = Marks(cutout: 0, thumbnails: [], frames: [])

        let cutout: CGFloat
        let thumbnails: [ChatRowThumbnail]
        let frames: [CGRect]
    }

    private static func addMarks(
        to content: inout ListRowContent,
        chat: ChatSummary,
        y: CGFloat,
        theme: ListTheme
    ) -> Marks {
        guard let preview = chat.preview else {
            return .none
        }

        var cutout: CGFloat = 0
        let lineHeight = theme.subtitleFont.lineHeight
        if preview.isForwarded {
            let frame = CGRect(x: textX, y: y, width: markSide, height: lineHeight)
            content.elements.append(
                icon("arrowshape.turn.up.right.fill", size: 10, color: theme.secondary, frame: frame)
            )
            cutout += markSide + cutoutGap
        }
        let frames = preview.thumbnails.indices.map { index in
            CGRect(
                x: textX + cutout + CGFloat(index) * (thumbnailSide + 2),
                y: y + (lineHeight - thumbnailSide) / 2,
                width: thumbnailSide,
                height: thumbnailSide
            )
        }
        if let last = frames.last {
            cutout = last.maxX - textX + cutoutGap
        }

        return Marks(cutout: cutout, thumbnails: preview.thumbnails, frames: frames)
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

        let titleRight = addStatus(
            to: &content,
            chat: chat,
            right: time.frame.minX - 6,
            height: timeSize.height,
            theme: theme
        )

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

    static func height(theme: ListTheme) -> CGFloat {
        max(76, (8 + theme.titleFont.lineHeight + 3 + theme.subtitleFont.lineHeight * 2 + 10).rounded(.up))
    }

    fileprivate static func text(
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

    fileprivate static func measure(_ string: String, font: UIFont, width: CGFloat, lines: UInt) -> CGSize {
        let attributed = NSAttributedString(string: string, attributes: [.font: font])

        return ListRowContent.measure(attributed, width: width, lines: lines)
    }

    fileprivate static func icon(_ symbol: String, size: CGFloat, color: UIColor, frame: CGRect) -> ListRowElement {
        .image(ListRowSymbols.image(symbol, size: size, color: color), frame: frame)
    }

    fileprivate static func badge(_ count: Int, muted: Bool, theme: ListTheme) -> ChatRowBadge {
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

    fileprivate static func boldFont(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return font
        }

        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}

extension ChatRowLayout {
    fileprivate static func indent(_ message: NSMutableAttributedString, by cutout: CGFloat) {
        guard cutout > 0 else {
            return
        }

        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = cutout
        message.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: message.length))
    }

    fileprivate static func addMessage(
        _ message: NSAttributedString,
        tags: [ChatRowTag],
        to content: inout ListRowContent,
        origin: CGPoint,
        width: CGFloat
    ) -> CGRect {
        let lines: UInt = tags.isEmpty ? 2 : 1
        let size = ListRowContent.measure(message, width: width, lines: lines)
        let frame = CGRect(origin: origin, size: size)
        content.elements.append(.text(message, lines: lines, frame: frame))

        return frame
    }

    fileprivate static func addTags(
        _ tags: [ChatRowTag],
        to content: inout ListRowContent,
        y: CGFloat,
        right: CGFloat,
        theme: ListTheme
    ) {
        let font = theme.subtitleFont.withSize(11)
        let height: CGFloat = 16
        var x = textX
        for tag in tags {
            let title = NSAttributedString(string: tag.title, attributes: [.font: font, .foregroundColor: tag.color])
            let size = ListRowContent.measure(title, width: right - textX, lines: 1)
            let frame = CGRect(x: x, y: y, width: size.width + 10, height: height)
            guard frame.maxX <= right else {
                return
            }

            content.elements.append(.box(tag.color.withAlphaComponent(0.16), cornerRadius: 4, frame: frame))
            let origin = CGPoint(x: x + 5, y: y + (height - size.height) / 2)
            content.elements.append(.text(title, lines: 1, frame: CGRect(origin: origin, size: size)))
            x = frame.maxX + 4
        }
    }

    fileprivate static func addStatus(
        to content: inout ListRowContent,
        chat: ChatSummary,
        right: CGFloat,
        height: CGFloat,
        theme: ListTheme
    ) -> CGFloat {
        let single = CGRect(x: right - 16, y: 10, width: 16, height: height)
        if chat.isFailed {
            content.elements.append(icon("exclamationmark.circle.fill", size: 13, color: .systemRed, frame: single))

            return single.minX - 4
        }

        if chat.isSending {
            content.elements.append(icon("clock", size: 11, color: theme.secondary, frame: single))

            return single.minX - 4
        }

        guard let read = chat.outgoingRead else {
            return right
        }

        content.elements.append(icon("checkmark", size: 11, color: theme.accent, frame: single))
        guard read else {
            return single.minX - 4
        }

        let second = single.offsetBy(dx: -5, dy: 0)
        content.elements.append(icon("checkmark", size: 11, color: theme.accent, frame: second))

        return second.minX - 4
    }

    fileprivate static func addBadge(
        to content: inout ListRowContent,
        symbol: String,
        color: UIColor,
        right: CGFloat,
        bottom: CGFloat
    ) -> CGFloat {
        let side: CGFloat = 22
        let frame = CGRect(x: right - side, y: bottom - side, width: side, height: side)
        content.elements.append(.box(color, cornerRadius: side / 2, frame: frame))
        content.elements.append(icon(symbol, size: 11, color: .white, frame: frame))

        return frame.minX - 4
    }

    fileprivate static func addTrailing(
        to content: inout ListRowContent,
        chat: ChatSummary,
        grayBadge: Bool,
        width: CGFloat,
        height: CGFloat,
        theme: ListTheme
    ) -> CGFloat {
        var right = width - rightInset
        var hasBadge = false
        if chat.unread > 0 {
            let badge = badge(chat.unread, muted: chat.isMuted || grayBadge, theme: theme)
            let origin = CGPoint(x: right - badge.size.width, y: height - 12 - badge.size.height)
            content.elements += badge.elements(at: origin)
            right = origin.x - 4
            hasBadge = true
        }
        if chat.unreadMentions > 0 {
            right = addBadge(to: &content, symbol: "at", color: theme.accent, right: right, bottom: height - 12)
            hasBadge = true
        }
        if chat.unreadReactions > 0 {
            right = addBadge(to: &content, symbol: "heart.fill", color: .systemPink, right: right, bottom: height - 12)
            hasBadge = true
        }
        if hasBadge {
            return right - 4
        }

        if chat.isPinned {
            let frame = CGRect(x: width - rightInset - 18, y: height - 34, width: 18, height: 22)
            content.elements.append(icon("pin.fill", size: 13, color: theme.secondary, frame: frame))

            return frame.minX - 8
        }

        return width - rightInset
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
