import Foundation

public struct MessageEntity: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case spoiler
        case mention(userID: String)
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
}
