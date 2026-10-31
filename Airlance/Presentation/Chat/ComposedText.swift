import ChatHistory
import UIKit

struct ComposedText {
    static let spoilerKey = NSAttributedString.Key("AirlanceSpoiler")
    static let mentionKey = NSAttributedString.Key("AirlanceMention")

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
        let length = (trimmed as NSString).length
        var entities: [MessageEntity] = []
        let whole = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttributes(in: whole) { attributes, range, _ in
            let clipped = NSIntersectionRange(range, NSRange(location: start, length: length))
            guard clipped.length > 0 else {
                return
            }

            let location = clipped.location - start
            if attributes[Self.spoilerKey] != nil {
                entities.append(MessageEntity(.spoiler, location: location, length: clipped.length))
            }
            if let userID = attributes[Self.mentionKey] as? String {
                entities.append(MessageEntity(.mention(userID: userID), location: location, length: clipped.length))
            }
        }
        self.init(text: trimmed, entities: Self.merged(entities))
    }

    func attributed(base: [NSAttributedString.Key: Any], style: ComposerStyle) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: base)
        for entity in MessageEntity.valid(entities, in: text) {
            switch entity.kind {
            case .spoiler:
                result.addAttributes(style.spoiler, range: entity.range)
            case .mention(let userID):
                result.addAttributes(style.mention(userID), range: entity.range)
            }
        }

        return result
    }

    private static func merged(_ entities: [MessageEntity]) -> [MessageEntity] {
        var result: [MessageEntity] = []
        for entity in entities {
            if let last = result.last, last.kind == entity.kind, last.location + last.length == entity.location {
                let length = last.length + entity.length
                result[result.count - 1] = MessageEntity(last.kind, location: last.location, length: length)
            } else {
                result.append(entity)
            }
        }

        return result
    }
}

struct ComposerStyle {
    let accent: UIColor
    let spoilerFill: UIColor

    var spoiler: [NSAttributedString.Key: Any] {
        [ComposedText.spoilerKey: true, .backgroundColor: spoilerFill]
    }

    func mention(_ userID: String) -> [NSAttributedString.Key: Any] {
        [ComposedText.mentionKey: userID, .foregroundColor: accent]
    }
}
