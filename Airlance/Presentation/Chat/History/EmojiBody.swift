@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct EmojiBody {
    private static let sizes: [CGFloat] = [64, 52, 42]

    let text: String
    let input: MessageBubbleInput

    static func fits(_ text: String, input: MessageBubbleInput) -> Bool {
        let message = input.message
        guard
            message.reply == nil,
            message.forward == nil,
            message.link == nil,
            message.entities.isEmpty,
            message.videoReactions.isEmpty,
            input.reactions.isEmpty,
            input.channel == nil,
            input.translationNote == nil
        else {
            return false
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return (1...sizes.count).contains(trimmed.count) && trimmed.allSatisfy(isEmoji)
    }

    private static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let first = scalars.first else {
            return false
        }

        let properties = first.properties

        return properties.isEmojiPresentation || properties.isEmoji && (scalars.count > 1 || first.value > 0x238C)
    }

    func make(style: HistoryStyle) -> BubbleBody {
        let message = input.message
        let emoji = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let font = UIFont.systemFont(ofSize: Self.sizes[min(emoji.count, Self.sizes.count) - 1])
        let label = MessageBubbleLayout.label(emoji, font: font, color: style.text(outgoing: false), width: 320)
        let delivery = message.isOutgoing ? message.delivery : nil
        let meta = MessageMeta(input, delivery: delivery, style: style, onMedia: true)
        let width = ceil(max(label.frame.width, meta.size.width + 12))
        let height = ceil(label.frame.maxY + 4 + meta.size.height + 2)
        let content = ASDisplayNode()
        content.isLayerBacked = true
        label.frame.origin = CGPoint(x: message.isOutgoing ? width - label.frame.width : 0, y: 0)
        content.addSubnode(label)
        let metaFrame = meta.place(in: content, bottomRight: CGPoint(x: width - 6, y: height - 2))
        let size = CGSize(width: width, height: height)
        content.frame = CGRect(origin: .zero, size: size)
        var body = BubbleBody(size: size, content: content)
        body.isBare = true
        if message.effect != nil {
            body.actions.append(BubbleAction(frame: metaFrame.insetBy(dx: -8, dy: -8), kind: .effect))
        }

        return body
    }
}
