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
        let meta = MessageMeta(time: input.timeText, delivery: outgoing ? message.delivery : nil, style: style)
        let header = BubbleHeader(input, style: style, maxWidth: maxContent, scale: scale)
        let card = card(style: style, maxWidth: maxContent)
        let textNode = MessageBubbleLayout.text(
            text,
            outgoing: outgoing,
            metaWidth: card == nil ? meta.size.width : 0,
            style: style,
            width: maxContent
        )
        let contentWidth = max(textNode.frame.width, header.size.width, card?.size.width ?? 0, meta.size.width)
        let width = ceil(contentWidth + padding.left + padding.right)
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: .zero, content: content)
        if !textNode.linkAttributeNames.isEmpty {
            body.linkText = textNode
        }
        var y = padding.top
        if !header.isEmpty {
            body.add(header.place(in: content, at: CGPoint(x: padding.left, y: y), width: contentWidth))
            y += header.size.height + 4
        }
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
