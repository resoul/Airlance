@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct TextBody {
    let text: String
    let input: MessageBubbleInput
    let scale: CGFloat
    let maxBubble: CGFloat

    func make(style: HistoryStyle) -> BubbleBody {
        let padding = MessageBubbleLayout.padding
        let message = input.message
        let outgoing = message.isOutgoing
        let maxContent = maxBubble - padding.left - padding.right
        let meta = MessageMeta(input, delivery: outgoing ? message.delivery : nil, style: style)
        let header = BubbleHeader(input, style: style, maxWidth: maxContent, scale: scale)
        let card = card(style: style, maxWidth: maxContent)
        let textNode = MessageBubbleLayout.text(
            text,
            entities: message.entities,
            outgoing: outgoing,
            metaWidth: card == nil ? meta.size.width : 0,
            style: style,
            width: maxContent
        )
        let note = translationNote(style: style, width: maxContent)
        let cardWidth = max(card?.size.width ?? 0, footerWidth(style: style))
        let noteWidth = note?.frame.width ?? 0
        let contentWidth = max(textNode.frame.width, header.size.width, cardWidth, meta.size.width, noteWidth)
        let width = ceil(contentWidth + padding.left + padding.right)
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: .zero, content: content)
        body.text = textNode
        var y = placeTop(header, note: note, in: &body, width: contentWidth)
        textNode.frame.origin = CGPoint(x: padding.left, y: y)
        content.addSubnode(textNode)
        y = textNode.frame.maxY
        if let card {
            body.add(card.place(in: content, at: CGPoint(x: padding.left, y: y + 6), width: contentWidth))
            y += 6 + card.size.height + 3 + meta.size.height
        }
        meta.place(in: content, bottomRight: CGPoint(x: width - padding.right, y: y))
        let size = CGSize(width: width, height: ceil(y + padding.bottom))
        content.frame = CGRect(origin: .zero, size: size)
        body.size = size

        return body
    }

    private func translationNote(style: HistoryStyle, width: CGFloat) -> ASTextNode? {
        input.translationNote.map { note in
            let color = style.meta(outgoing: input.message.isOutgoing)

            return MessageBubbleLayout.label(note, font: style.metaFont, color: color, width: width)
        }
    }

    private func placeTop(
        _ header: BubbleHeader,
        note: ASTextNode?,
        in body: inout BubbleBody,
        width: CGFloat
    ) -> CGFloat {
        let padding = MessageBubbleLayout.padding
        var y = padding.top
        if !header.isEmpty {
            body.add(header.place(in: body.content, at: CGPoint(x: padding.left, y: y), width: width))
            y += header.size.height + 4
        }
        if let note {
            note.frame.origin = CGPoint(x: padding.left, y: y)
            body.content.addSubnode(note)
            body.translationNote = note
            y += note.frame.height + 2
        }

        return y
    }

    private func footerWidth(style: HistoryStyle) -> CGFloat {
        let comments = input.channel?.comments == nil ? 0 : CommentsFooter.minWidth
        let reactions = ReactionsFooter.preferredWidth(input.reactions, style: style)
        let padding = MessageBubbleLayout.padding

        return max(0, min(max(comments, reactions), maxBubble) - padding.left - padding.right)
    }

    private func card(style: HistoryStyle, maxWidth: CGFloat) -> LinkCard? {
        guard let link = input.message.link, let preview = link.preview else {
            return nil
        }

        let outgoing = input.message.isOutgoing

        return LinkCard(link, preview: preview, outgoing: outgoing, style: style, maxWidth: maxWidth, scale: scale)
    }
}

extension BubbleBody {
    mutating func add(_ placed: (MediaTile?, BubbleAction?)) {
        if let tile = placed.0 {
            images.append(tile)
        }
        if let action = placed.1 {
            actions.append(action)
        }
    }
}
