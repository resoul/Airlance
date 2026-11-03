@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

final class MessageTextNode: ASTextNode {
    struct Block {
        let range: NSRange
        let isQuote: Bool
    }

    var blocks: [Block] = []
    var barColor = UIColor.clear
    var quoteFill = UIColor.clear
    var preFill = UIColor.clear

    func place(in content: ASDisplayNode, at origin: CGPoint, width: CGFloat) {
        frame.origin = origin
        for block in blocks {
            let rects = rects(forTextRange: block.range).map(\.cgRectValue)
            guard let first = rects.first else {
                continue
            }

            let union = rects.dropFirst().reduce(first) { result, rect in
                result.union(rect)
            }
            let frame = CGRect(x: origin.x, y: origin.y + union.minY - 3, width: width, height: union.height + 6)
            content.addSubnode(background(frame, isQuote: block.isQuote))
        }
        content.addSubnode(self)
    }

    private func background(_ frame: CGRect, isQuote: Bool) -> ASDisplayNode {
        let node = ASDisplayNode()
        node.isLayerBacked = true
        node.frame = frame
        node.cornerRadius = isQuote ? 4 : 6
        node.clipsToBounds = true
        node.backgroundColor = isQuote ? quoteFill : preFill
        guard isQuote else {
            return node
        }

        let bar = ASDisplayNode()
        bar.isLayerBacked = true
        bar.backgroundColor = barColor
        bar.frame = CGRect(x: 0, y: 0, width: 3, height: frame.height)
        node.addSubnode(bar)

        return node
    }
}

extension MessageBubbleLayout {
    static let hashtagScheme = "airlance-hashtag"

    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
            | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
            | NSTextCheckingResult.CheckingType.date.rawValue
    )
    private static let hashtag = try? NSRegularExpression(
        pattern: "(?<![\\p{L}\\p{N}_#/])#[\\p{L}\\p{N}_]*\\p{L}[\\p{L}\\p{N}_]*"
    )

    static func text(
        _ string: String,
        entities: [MessageEntity] = [],
        outgoing: Bool,
        metaWidth: CGFloat,
        style: HistoryStyle,
        width: CGFloat,
        maxLines: Int = 0
    ) -> MessageTextNode {
        let entities = MessageEntity.valid(entities, in: string)
        let color = style.text(outgoing: outgoing)
        let tint = style.tint(outgoing: outgoing)
        let attributed = NSMutableAttributedString(
            string: string,
            attributes: [.font: style.textFont, .foregroundColor: color]
        )
        TextFormatting.apply(entities, to: attributed, font: style.textFont, codeFill: color.withAlphaComponent(0.1))
        let hasMentions = addMentions(entities, to: attributed, color: tint)
        let skipped = entities.filter(\.isCode).map(\.range)
        let hasLinks = addLinks(to: attributed, color: tint, skipping: skipped)
        let hasTags = addHashtags(to: attributed, color: tint, skipping: skipped + linkRanges(in: attributed))
        if metaWidth > 0 {
            let endsWithBlock = entities.contains { entity in
                entity.isBlock && NSMaxRange(entity.range) >= (string as NSString).length
            }
            attributed.append(spacer(metaWidth, style: style, newLine: endsWithBlock))
        }
        let node = MessageTextNode()
        node.isLayerBacked = true
        node.linkAttributeNames = hasLinks || hasMentions || hasTags ? [linkKey.rawValue] : []
        node.maximumNumberOfLines = UInt(maxLines)
        node.truncationMode = .byTruncatingTail
        node.attributedText = attributed
        node.blocks = entities.filter(\.isBlock).map { entity in
            MessageTextNode.Block(range: entity.range, isQuote: entity.kind == .quote)
        }
        node.barColor = tint
        node.quoteFill = tint.withAlphaComponent(0.12)
        node.preFill = color.withAlphaComponent(0.08)
        node.frame = CGRect(origin: .zero, size: measure(node, width: width))

        return node
    }

    private static func spacer(_ width: CGFloat, style: HistoryStyle, newLine: Bool) -> NSAttributedString {
        NSAttributedString(
            string: (newLine ? "\n" : "") + " \u{00A0}",
            attributes: [.font: style.metaFont, .foregroundColor: UIColor.clear, .kern: max(0, width - 2)]
        )
    }

    private static func addMentions(
        _ entities: [MessageEntity],
        to text: NSMutableAttributedString,
        color: UIColor
    ) -> Bool {
        var found = false
        for entity in entities {
            guard case .mention(let userID) = entity.kind, let url = URL(string: "\(mentionScheme):\(userID)") else {
                continue
            }

            text.addAttributes([linkKey: url, .foregroundColor: color], range: entity.range)
            found = true
        }

        return found
    }

    private static func addLinks(to text: NSMutableAttributedString, color: UIColor, skipping: [NSRange]) -> Bool {
        let string = text.string
        let matches = detector?.matches(in: string, range: NSRange(string.startIndex..., in: string)) ?? []
        var found = false
        for match in matches where !intersects(match.range, skipping) {
            guard let url = url(for: match) else {
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
            found = true
        }

        return found
    }

    private static func url(for match: NSTextCheckingResult) -> URL? {
        switch match.resultType {
        case .phoneNumber:
            let digits = (match.phoneNumber ?? "").filter { character in
                character == "+" || character.isASCII && character.isNumber
            }

            return digits.count < 5 ? nil : URL(string: "tel:" + digits)
        case .date:
            return match.date.flatMap { date in
                URL(string: "calshow:\(Int(date.timeIntervalSinceReferenceDate))")
            }
        default:
            return match.url
        }
    }

    private static func addHashtags(to text: NSMutableAttributedString, color: UIColor, skipping: [NSRange]) -> Bool {
        let string = text.string
        let matches = hashtag?.matches(in: string, range: NSRange(location: 0, length: text.length)) ?? []
        var found = false
        for match in matches where !intersects(match.range, skipping) {
            let tag = (string as NSString).substring(with: match.range).dropFirst()
            let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            guard let url = URL(string: "\(hashtagScheme):\(encoded)") else {
                continue
            }

            text.addAttributes([linkKey: url, .foregroundColor: color], range: match.range)
            found = true
        }

        return found
    }

    private static func linkRanges(in text: NSAttributedString) -> [NSRange] {
        var ranges: [NSRange] = []
        text.enumerateAttribute(linkKey, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if value != nil {
                ranges.append(range)
            }
        }

        return ranges
    }

    private static func intersects(_ range: NSRange, _ ranges: [NSRange]) -> Bool {
        ranges.contains { other in
            NSIntersectionRange(range, other).length > 0
        }
    }
}
