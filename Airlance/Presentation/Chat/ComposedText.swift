import ChatHistory
import UIKit

struct ComposedText {
    static let spoilerKey = NSAttributedString.Key("AirlanceSpoiler")
    static let mentionKey = NSAttributedString.Key("AirlanceMention")
    static let formats: [(kind: MessageEntity.Kind, key: NSAttributedString.Key)] = [
        (.bold, NSAttributedString.Key("AirlanceBold")),
        (.italic, NSAttributedString.Key("AirlanceItalic")),
        (.strikethrough, NSAttributedString.Key("AirlanceStrikethrough")),
        (.code, NSAttributedString.Key("AirlanceCode")),
        (.pre, NSAttributedString.Key("AirlancePre")),
        (.quote, NSAttributedString.Key("AirlanceQuote")),
        (.spoiler, spoilerKey),
    ]

    var text: String
    var entities: [MessageEntity]

    init(text: String, entities: [MessageEntity] = []) {
        self.text = text
        self.entities = entities
    }

    init(attributed: NSAttributedString) {
        let full = attributed.string as NSString
        let trimmed = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = trimmed.isEmpty ? 0 : full.range(of: trimmed).location
        let kept = NSRange(location: start, length: (trimmed as NSString).length)
        let entities = Self.entities(in: attributed).compactMap { entity in
            let clipped = NSIntersectionRange(entity.range, kept)

            return clipped.length > 0
                ? MessageEntity(entity.kind, location: clipped.location - start, length: clipped.length)
                : nil
        }
        self.init(text: trimmed, entities: entities)
    }

    static func key(for kind: MessageEntity.Kind) -> NSAttributedString.Key? {
        formats.first { format in
            format.kind == kind
        }?.key
    }

    static func entities(in attributed: NSAttributedString) -> [MessageEntity] {
        var entities: [MessageEntity] = []
        let whole = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttributes(in: whole) { attributes, range, _ in
            for format in formats where attributes[format.key] != nil {
                entities.append(MessageEntity(format.kind, location: range.location, length: range.length))
            }
            if let userID = attributes[mentionKey] as? String {
                let mention = MessageEntity.Kind.mention(userID: userID)
                entities.append(MessageEntity(mention, location: range.location, length: range.length))
            }
        }

        return MessageEntity.merged(entities)
    }

    func attributed(base: [NSAttributedString.Key: Any], style: ComposerStyle) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: base)
        for entity in MessageEntity.valid(entities, in: text) {
            if case .mention(let userID) = entity.kind {
                result.addAttribute(Self.mentionKey, value: userID, range: entity.range)
            } else if let key = Self.key(for: entity.kind) {
                result.addAttribute(key, value: true, range: entity.range)
            }
        }
        style.render(result, base: base)

        return result
    }
}

struct ComposerStyle {
    let accent: UIColor
    let spoilerFill: UIColor

    func mention(_ userID: String) -> [NSAttributedString.Key: Any] {
        [ComposedText.mentionKey: userID, .foregroundColor: accent]
    }

    func render(_ text: NSMutableAttributedString, base: [NSAttributedString.Key: Any]) {
        let whole = NSRange(location: 0, length: text.length)
        for key in [NSAttributedString.Key.obliqueness, .strikethroughStyle, .paragraphStyle, .backgroundColor] {
            text.removeAttribute(key, range: whole)
        }
        text.addAttributes(base, range: whole)
        let entities = MessageEntity.valid(ComposedText.entities(in: text), in: text.string)
        let font = base[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
        TextFormatting.apply(entities, to: text, font: font, codeFill: spoilerFill)
        for entity in entities {
            switch entity.kind {
            case .spoiler:
                text.addAttribute(.backgroundColor, value: spoilerFill, range: entity.range)
            case .mention:
                text.addAttribute(.foregroundColor, value: accent, range: entity.range)
            case .pre:
                text.addAttribute(.backgroundColor, value: spoilerFill.withAlphaComponent(0.4), range: entity.range)
            case .quote:
                text.addAttribute(.backgroundColor, value: accent.withAlphaComponent(0.12), range: entity.range)
            case .bold, .italic, .strikethrough, .code:
                break
            }
        }
    }
}
