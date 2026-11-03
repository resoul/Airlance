import Foundation

public struct MessageEntity: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case spoiler
        case mention(userID: String)
        case bold
        case italic
        case strikethrough
        case code
        case pre
        case quote
    }

    public let kind: Kind
    public let location: Int
    public let length: Int

    public init(_ kind: Kind, location: Int, length: Int) {
        self.kind = kind
        self.location = location
        self.length = length
    }

    public var range: NSRange {
        NSRange(location: location, length: length)
    }

    public var isSpoiler: Bool {
        kind == .spoiler
    }

    public var isBlock: Bool {
        kind == .pre || kind == .quote
    }

    public var isCode: Bool {
        kind == .code || kind == .pre
    }
}

extension MessageEntity {
    public static func valid(_ entities: [MessageEntity], in text: String) -> [MessageEntity] {
        let length = (text as NSString).length

        return entities.filter { entity in
            entity.length > 0 && entity.location >= 0 && entity.location + entity.length <= length
        }
    }

    public static func masked(_ text: String, entities: [MessageEntity]) -> String {
        let string = NSMutableString(string: text)
        for entity in valid(entities, in: text) where entity.isSpoiler {
            string.replaceCharacters(in: entity.range, with: String(repeating: "⠿", count: entity.length))
        }

        return string as String
    }

    public static func merged(_ entities: [MessageEntity]) -> [MessageEntity] {
        let sorted = entities.sorted { lhs, rhs in
            lhs.location < rhs.location
        }
        var result: [MessageEntity] = []
        for entity in sorted {
            let index = result.lastIndex { other in
                other.kind == entity.kind
            }
            if let index, result[index].location + result[index].length >= entity.location {
                let last = result[index]
                let end = max(last.location + last.length, entity.location + entity.length)
                result[index] = MessageEntity(last.kind, location: last.location, length: end - last.location)
            } else {
                result.append(entity)
            }
        }

        return result
    }
}
