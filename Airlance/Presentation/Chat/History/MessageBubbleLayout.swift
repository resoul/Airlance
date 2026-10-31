@preconcurrency import AsyncDisplayKit
import ChatHistory
import MediaLoader
import UIKit

struct MessageBubbleInput: Sendable, Hashable {
    let message: HistoryMessage
    let grouping: HistoryGrouping
    let showsName: Bool
    let reservesAvatar: Bool
    let timeText: String
    let reply: ReplyQuote?
    let forwardTitle: String?
    var channel: ChannelPostParts?
    var reactions: [ReactionChip] = []
    var translationNote: String?
    var pollDraft: Set<Int> = []
}

struct MessageTranslation: Sendable, Hashable {
    let original: String
    let text: String
    let note: String
}

struct ChannelPostParts: Sendable, Hashable {
    let views: String?
    let signature: String?
    let comments: String?
    let commenters: [MessageCommenter]
}

struct MediaTile {
    let node: ASImageNode
    let request: MediaImageRequest
    var overlay: ASDisplayNode?

    func setHidden(_ hidden: Bool) {
        node.isHidden = hidden
        overlay?.isHidden = hidden
    }
}

struct BubbleBody {
    var size: CGSize
    let content: ASDisplayNode
    var tiles: [MediaTile] = []
    var images: [MediaTile] = []
    var actions: [BubbleAction] = []
    var text: ASTextNode?
    var translationNote: ASTextNode?
    var pollBars: [ASDisplayNode] = []
    var videoNote: VideoNoteParts?
    var voice: VoiceParts?
    var fileIcon: CGRect?
}

final class MessageBubbleLayout: @unchecked Sendable {
    static let sideInset: CGFloat = 6
    static let tailWidth: CGFloat = 6
    static let avatarSize: CGFloat = 34
    static let avatarSpacing: CGFloat = 4
    static let padding = UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)
    static let linkKey = NSAttributedString.Key("AirlanceURL")
    static let mentionScheme = "airlance-mention"

    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    let key: Int
    let messageID: String
    let width: CGFloat
    let isOutgoing: Bool
    let grouping: HistoryGrouping
    let bubbleFrame: CGRect
    let height: CGFloat
    let content: ASDisplayNode
    let tiles: [MediaTile]
    let images: [MediaTile]
    let actions: [BubbleAction]
    let text: ASTextNode?
    let translationNote: ASTextNode?
    let spoilers: [NSRange]
    let pollBars: [ASDisplayNode]
    let videoNote: VideoNoteParts?
    let voice: VoiceParts?
    let fileIcon: CGRect?

    init(_ input: MessageBubbleInput, width: CGFloat, scale: CGFloat, style: HistoryStyle, poll: PollTitles? = nil) {
        let message = input.message
        let leading = input.reservesAvatar ? Self.avatarSize + Self.avatarSpacing : 0
        let maxBubble = Self.maximumBubbleWidth(in: width - leading)
        let body = Self.body(input, scale: scale, maxBubble: maxBubble, style: style, poll: poll)
        let top: CGFloat = input.channel != nil ? 14 : input.grouping.joinedTop ? 2 : 8
        let x = message.isOutgoing
            ? width - Self.sideInset - Self.tailWidth - body.size.width
            : Self.sideInset + leading + Self.tailWidth

        key = Self.key(input, style: style)
        messageID = message.id
        self.width = width
        isOutgoing = message.isOutgoing
        grouping = input.grouping
        bubbleFrame = CGRect(origin: CGPoint(x: x, y: top), size: body.size)
        height = top + body.size.height
        content = body.content
        tiles = body.tiles
        images = body.images
        actions = body.actions
        text = body.text
        translationNote = body.translationNote
        pollBars = body.pollBars
        videoNote = body.videoNote
        spoilers = body.text == nil ? [] : MessageEntity.valid(message.entities, in: message.content.text)
            .filter(\.isSpoiler)
            .map(\.range)
        voice = body.voice
        fileIcon = body.fileIcon
    }

    private static func body(
        _ input: MessageBubbleInput,
        scale: CGFloat,
        maxBubble: CGFloat,
        style: HistoryStyle,
        poll titles: PollTitles?
    ) -> BubbleBody {
        var body: BubbleBody
        switch input.message.content {
        case .text(let text):
            body = TextBody(text: text, input: input, scale: scale, maxBubble: maxBubble).make(style: style)
        case .photos(let photos, let caption):
            let media = MediaBody(photos: photos, caption: caption, input: input, scale: scale, maxBubble: maxBubble)
            body = media.make(style: style)
        case .voice(let voice):
            body = VoiceBody(voice: voice, input: input, scale: scale, maxBubble: maxBubble).make(style: style)
        case .file(let file, let caption):
            let parts = FileBody(file: file, caption: caption, input: input, scale: scale, maxBubble: maxBubble)
            body = parts.make(style: style)
        case .location(let location):
            let map = LocationBody(location: location, input: input, scale: scale, maxBubble: maxBubble)
            body = map.make(style: style)
        case .videoNote(let note):
            body = VideoNoteBody(note: note, input: input, scale: scale).make(style: style)
        case .poll(let poll):
            body = Self.pollBody(poll, input: input, scale: scale, maxBubble: maxBubble, style: style, titles: titles)
        case .service:
            body = TextBody(text: "", input: input, scale: scale, maxBubble: maxBubble).make(style: style)
        }
        ReactionsFooter.attach(
            input.reactions,
            to: &body,
            outgoing: input.message.isOutgoing,
            style: style,
            scale: scale
        )
        VideoReactionsFooter.attach(input.message.videoReactions, to: &body, scale: scale)
        if let channel = input.channel, let comments = channel.comments {
            CommentsFooter.attach(comments, parts: channel, to: &body, style: style, scale: scale)
        }

        return body
    }

    private static func pollBody(
        _ poll: MessagePoll,
        input: MessageBubbleInput,
        scale: CGFloat,
        maxBubble: CGFloat,
        style: HistoryStyle,
        titles: PollTitles?
    ) -> BubbleBody {
        guard let titles else {
            return TextBody(text: poll.question, input: input, scale: scale, maxBubble: maxBubble).make(style: style)
        }

        return PollBody(poll: poll, input: input, scale: scale, maxBubble: maxBubble, titles: titles).make(style: style)
    }

    static func key(_ input: MessageBubbleInput, style: HistoryStyle) -> Int {
        var hasher = Hasher()
        hasher.combine(input)
        hasher.combine(style)

        return hasher.finalize()
    }

    static func maximumBubbleWidth(in width: CGFloat) -> CGFloat {
        floor(min(width * 0.8, width - 64))
    }

    static func name(_ string: String, style: HistoryStyle, width: CGFloat) -> ASTextNode {
        label(string, font: style.nameFont, color: style.name, width: width)
    }

    static func label(_ string: String, font: UIFont, color: UIColor, width: CGFloat, lines: Int = 1) -> ASTextNode {
        let node = ASTextNode()
        node.isLayerBacked = true
        node.maximumNumberOfLines = UInt(lines)
        node.truncationMode = .byTruncatingTail
        node.attributedText = NSAttributedString(
            string: string.replacingOccurrences(of: "\n", with: " "),
            attributes: [.font: font, .foregroundColor: color]
        )
        node.frame = CGRect(origin: .zero, size: measure(node, width: width))

        return node
    }

    static func text(
        _ string: String,
        entities: [MessageEntity] = [],
        outgoing: Bool,
        metaWidth: CGFloat,
        style: HistoryStyle,
        width: CGFloat
    ) -> ASTextNode {
        let attributed = NSMutableAttributedString(
            string: string,
            attributes: [.font: style.textFont, .foregroundColor: style.text(outgoing: outgoing)]
        )
        let tint = style.tint(outgoing: outgoing)
        let hasMentions = addMentions(entities, to: attributed, color: tint)
        let hasLinks = addLinks(to: attributed, color: tint) || hasMentions
        let spacer = NSAttributedString(
            string: " \u{00A0}",
            attributes: [.font: style.metaFont, .foregroundColor: UIColor.clear, .kern: max(0, metaWidth - 2)]
        )
        if metaWidth > 0 {
            attributed.append(spacer)
        }
        let node = ASTextNode()
        node.isLayerBacked = true
        node.linkAttributeNames = hasLinks ? [linkKey.rawValue] : []
        node.attributedText = attributed
        node.frame = CGRect(origin: .zero, size: measure(node, width: width))

        return node
    }

    static func measure(_ node: ASTextNode, width: CGFloat) -> CGSize {
        let range = ASSizeRange(min: .zero, max: CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
        let size = node.layoutThatFits(range).size

        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    private static func addMentions(
        _ entities: [MessageEntity],
        to text: NSMutableAttributedString,
        color: UIColor
    ) -> Bool {
        var found = false
        for entity in MessageEntity.valid(entities, in: text.string) {
            guard case .mention(let userID) = entity.kind, let url = URL(string: "\(mentionScheme):\(userID)") else {
                continue
            }

            text.addAttributes([linkKey: url, .foregroundColor: color], range: entity.range)
            found = true
        }

        return found
    }

    private static func addLinks(to text: NSMutableAttributedString, color: UIColor) -> Bool {
        let string = text.string
        let matches = detector?.matches(in: string, range: NSRange(string.startIndex..., in: string)) ?? []
        for match in matches {
            guard let url = match.url else {
                continue
            }

            text.addAttributes(
                [
                    linkKey: url,
                    .foregroundColor: color,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: color.withAlphaComponent(0.5),
                ],
                range: match.range
            )
        }

        return !matches.isEmpty
    }
}

struct MessageMeta {
    let size: CGSize

    private let time: ASTextNode
    private let checks: ASImageNode?
    private let background: ASDisplayNode?

    init(_ input: MessageBubbleInput, delivery: DeliveryState?, style: HistoryStyle, onMedia: Bool = false) {
        let color = onMedia ? UIColor.white : style.meta(outgoing: delivery != nil)
        let time = ASTextNode()
        time.isLayerBacked = true
        time.maximumNumberOfLines = 1
        time.truncationMode = .byTruncatingHead
        time.attributedText = Self.text(input, font: style.metaFont, color: color)
        let range = ASSizeRange(min: .zero, max: CGSize(width: 220, height: 40))
        let timeSize = time.layoutThatFits(range).size
        time.frame = CGRect(origin: .zero, size: CGSize(width: ceil(timeSize.width), height: ceil(timeSize.height)))

        var width = time.frame.width
        if let delivery, let image = MessageChecks.image(delivery, color: color, failed: style.failed) {
            let node = ASImageNode()
            node.isLayerBacked = true
            node.contentMode = .center
            node.image = image
            node.frame = CGRect(origin: .zero, size: image.size)
            checks = node
            width += 3 + image.size.width
        } else {
            checks = nil
        }
        background = onMedia ? Self.mediaBackground() : nil
        self.time = time
        size = CGSize(width: ceil(width), height: time.frame.height)
    }

    private static func text(_ input: MessageBubbleInput, font: UIFont, color: UIColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let text = NSMutableAttributedString()
        if let signature = input.channel?.signature {
            text.append(NSAttributedString(string: signature + "  ", attributes: attributes))
        }
        if let views = input.channel?.views {
            let configuration = UIImage.SymbolConfiguration(font: font)
            if let eye = UIImage(systemName: "eye.fill", withConfiguration: configuration) {
                let attachment = NSTextAttachment(image: eye.withTintColor(color, renderingMode: .alwaysOriginal))
                attachment.bounds = CGRect(x: 0, y: font.descender / 2, width: eye.size.width, height: eye.size.height)
                text.append(NSAttributedString(attachment: attachment))
            }
            text.append(NSAttributedString(string: " " + views + "  ", attributes: attributes))
        }
        text.append(NSAttributedString(string: input.timeText, attributes: attributes))

        return text
    }

    func place(in content: ASDisplayNode, bottomRight: CGPoint) {
        var x = bottomRight.x - size.width
        let y = bottomRight.y - size.height
        if let background {
            let frame = CGRect(x: x, y: y, width: size.width, height: size.height).insetBy(dx: -6, dy: -2)
            background.frame = frame
            background.cornerRadius = frame.height / 2
            content.addSubnode(background)
        }
        time.frame.origin = CGPoint(x: x, y: y)
        content.addSubnode(time)
        guard let checks else {
            return
        }

        x = time.frame.maxX + 3
        checks.frame.origin = CGPoint(x: x, y: y + (size.height - checks.frame.height) / 2)
        content.addSubnode(checks)
    }

    private static func mediaBackground() -> ASDisplayNode {
        let node = ASDisplayNode()
        node.isLayerBacked = true
        node.backgroundColor = UIColor.black.withAlphaComponent(0.45)

        return node
    }
}
