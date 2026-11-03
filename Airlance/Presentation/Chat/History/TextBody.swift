@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct TextBody {
    let text: String
    let input: MessageBubbleInput
    let scale: CGFloat
    let maxBubble: CGFloat

    private static let collapsedLines = 18

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
            width: maxContent,
            maxLines: input.expandTitle == nil ? 0 : Self.collapsedLines
        )
        let expand = textNode.isTruncated ? expandLabel(style: style, width: maxContent - meta.size.width - 8) : nil
        let note = translationNote(style: style, width: maxContent)
        let cardWidth = max(card?.size.width ?? 0, footerWidth(style: style))
        let noteWidth = note?.frame.width ?? 0
        let expandWidth = (expand?.frame.width ?? 0) + (expand == nil ? 0 : meta.size.width + 8)
        let widths = [textNode.frame.width, header.size.width, cardWidth, meta.size.width, noteWidth, expandWidth]
        let contentWidth = widths.max() ?? 0
        let width = ceil(contentWidth + padding.left + padding.right)
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: .zero, content: content)
        body.text = textNode
        var y = placeTop(header, note: note, in: &body, width: contentWidth)
        textNode.place(in: content, at: CGPoint(x: padding.left, y: y), width: contentWidth)
        y = textNode.frame.maxY
        y = placeBottom(card: card, expand: expand, meta: meta, in: &body, top: y, width: contentWidth)
        let size = CGSize(width: width, height: ceil(y + padding.bottom))
        content.frame = CGRect(origin: .zero, size: size)
        body.size = size

        return body
    }

    private func placeBottom(
        card: LinkCard?,
        expand: ASTextNode?,
        meta: MessageMeta,
        in body: inout BubbleBody,
        top: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let padding = MessageBubbleLayout.padding
        var y = top
        if let expand {
            expand.frame.origin = CGPoint(x: padding.left, y: y + 4)
            body.content.addSubnode(expand)
            body.actions.append(BubbleAction(frame: expand.frame.insetBy(dx: -8, dy: -6), kind: .expand))
            y = max(expand.frame.maxY, y + 4 + meta.size.height)
        }
        if let card {
            let placed = card.place(in: body.content, at: CGPoint(x: padding.left, y: y + 6), width: width)
            body.add((placed.0, placed.1.map { action in
                [action]
            } ?? []))
            y += 6 + card.size.height + 3 + meta.size.height
        }
        let metaFrame = meta.place(in: body.content, bottomRight: CGPoint(x: width + padding.left, y: y))
        if input.message.effect != nil {
            body.actions.append(BubbleAction(frame: metaFrame.insetBy(dx: -8, dy: -8), kind: .effect))
        }

        return y
    }

    private func expandLabel(style: HistoryStyle, width: CGFloat) -> ASTextNode? {
        input.expandTitle.map { title in
            let font = HistoryStyle.bold(style.quoteFont)
            let color = style.tint(outgoing: input.message.isOutgoing)

            return MessageBubbleLayout.label(title, font: font, color: color, width: width)
        }
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
    mutating func add(_ placed: (MediaTile?, [BubbleAction])) {
        if let tile = placed.0 {
            images.append(tile)
        }
        actions.append(contentsOf: placed.1)
    }
}
