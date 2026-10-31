@preconcurrency import AsyncDisplayKit
import ChatHistory
import MediaLoader
import UIKit

struct ReplyQuote: Sendable, Hashable {
    let messageID: String
    let title: String
    let text: String
    let photo: MessagePhoto?
    let quote: MessageQuote?
}

struct BubbleAction {
    enum Kind {
        case reply(String, MessageQuote?)
        case url(URL)
        case voice
        case file
        case comments
        case reaction(String)
        case pollOption(Int)
        case pollVote
        case pollResults
        case pollExplanation
        case videoNote
        case videoReaction(String)
    }

    let frame: CGRect
    let kind: Kind
}

struct BubbleHeader {
    private static let quoteHeight: CGFloat = 42
    private static let thumbSize: CGFloat = 32

    let size: CGSize

    private let name: ASTextNode?
    private let forward: ASTextNode?
    private let quote: (title: ASTextNode, text: ASTextNode, width: CGFloat)?
    private let input: MessageBubbleInput
    private let style: HistoryStyle
    private let scale: CGFloat

    var isEmpty: Bool {
        size.height == 0
    }

    init(_ input: MessageBubbleInput, style: HistoryStyle, maxWidth: CGFloat, scale: CGFloat) {
        let message = input.message
        let tint = style.tint(outgoing: message.isOutgoing)
        self.input = input
        self.style = style
        self.scale = scale
        name = input.showsName ? MessageBubbleLayout.name(message.authorName, style: style, width: maxWidth) : nil
        forward = message.forward.flatMap { forward in
            input.forwardTitle.map { title in
                Self.forward(title: title, name: forward.fromName, tint: tint, style: style, width: maxWidth)
            }
        }
        quote = input.reply.map { reply in
            Self.quote(reply, outgoing: message.isOutgoing, style: style, maxWidth: maxWidth)
        }
        var parts: [CGSize] = []
        for case let node? in [name, forward] {
            parts.append(node.frame.size)
        }
        if let quote {
            parts.append(CGSize(width: quote.width, height: Self.quoteHeight))
        }
        let spacing = CGFloat(max(0, parts.count - 1)) * 3
        size = CGSize(
            width: parts.map(\.width).max() ?? 0,
            height: parts.map(\.height).reduce(0, +) + spacing
        )
    }

    func place(in content: ASDisplayNode, at origin: CGPoint, width: CGFloat) -> (MediaTile?, BubbleAction?) {
        var y = origin.y
        for case let node? in [name, forward] {
            node.frame.origin = CGPoint(x: origin.x, y: y)
            content.addSubnode(node)
            y = node.frame.maxY + 3
        }
        guard let quote, let reply = input.reply else {
            return (nil, nil)
        }

        let frame = CGRect(x: origin.x, y: y, width: width, height: Self.quoteHeight)
        let tint = style.tint(outgoing: input.message.isOutgoing)
        content.addSubnode(Self.quoteBackground(frame: frame, tint: tint, alpha: 0.12))
        var textX = frame.minX + 10
        var tile: MediaTile?
        if let photo = reply.photo {
            tile = thumbnail(photo, at: CGPoint(x: textX, y: frame.midY - Self.thumbSize / 2), in: content)
            textX += Self.thumbSize + 7
        }
        let textWidth = frame.maxX - 8 - textX
        quote.title.frame = CGRect(x: textX, y: frame.minY + 4, width: textWidth, height: quote.title.frame.height)
        let textY = quote.title.frame.maxY
        quote.text.frame = CGRect(x: textX, y: textY, width: textWidth, height: quote.text.frame.height)
        content.addSubnode(quote.title)
        content.addSubnode(quote.text)

        return (tile, BubbleAction(frame: frame, kind: .reply(reply.messageID, reply.quote)))
    }

    private func thumbnail(_ photo: MessagePhoto, at origin: CGPoint, in content: ASDisplayNode) -> MediaTile {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.backgroundColor = style.mediaPlaceholder
        node.cornerRadius = 4
        node.frame = CGRect(origin: origin, size: CGSize(width: Self.thumbSize, height: Self.thumbSize))
        content.addSubnode(node)
        let corners = MediaCorners(topLeft: 4, topRight: 4, bottomLeft: 4, bottomRight: 4)
        let request = MediaImageRequest(source: photo.source, size: node.frame.size, scale: scale, corners: corners)

        return MediaTile(node: node, request: request)
    }

    private static func forward(
        title: String,
        name: String,
        tint: UIColor,
        style: HistoryStyle,
        width: CGFloat
    ) -> ASTextNode {
        let text = NSMutableAttributedString(
            string: title + "\n",
            attributes: [.font: style.quoteFont, .foregroundColor: tint]
        )
        text.append(NSAttributedString(string: name, attributes: [.font: style.nameFont, .foregroundColor: tint]))
        let node = ASTextNode()
        node.isLayerBacked = true
        node.maximumNumberOfLines = 2
        node.truncationMode = .byTruncatingTail
        node.attributedText = text
        node.frame = CGRect(origin: .zero, size: MessageBubbleLayout.measure(node, width: width))

        return node
    }

    private static func quote(
        _ reply: ReplyQuote,
        outgoing: Bool,
        style: HistoryStyle,
        maxWidth: CGFloat
    ) -> (title: ASTextNode, text: ASTextNode, width: CGFloat) {
        let insets: CGFloat = 10 + 8 + (reply.photo == nil ? 0 : thumbSize + 7)
        let width = maxWidth - insets
        let title = MessageBubbleLayout.label(
            reply.title,
            font: style.nameFont,
            color: style.tint(outgoing: outgoing),
            width: width
        )
        let text = MessageBubbleLayout.label(
            reply.text,
            font: style.quoteFont,
            color: style.text(outgoing: outgoing),
            width: width
        )

        return (title, text, min(maxWidth, max(title.frame.width, text.frame.width) + insets))
    }

    static func quoteBackground(frame: CGRect, tint: UIColor, alpha: CGFloat) -> ASDisplayNode {
        let background = ASDisplayNode()
        background.isLayerBacked = true
        background.backgroundColor = tint.withAlphaComponent(alpha)
        background.cornerRadius = 6
        background.clipsToBounds = true
        background.frame = frame
        let bar = ASDisplayNode()
        bar.isLayerBacked = true
        bar.backgroundColor = tint
        bar.frame = CGRect(x: 0, y: 0, width: 3, height: frame.height)
        background.addSubnode(bar)

        return background
    }
}
