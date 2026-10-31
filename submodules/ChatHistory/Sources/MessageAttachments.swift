import Foundation

public struct MessageReply: Sendable, Hashable {
    public let messageID: String
    public let authorName: String
    public let isOutgoing: Bool
    public let text: String
    public let photo: MessagePhoto?
    public var isVoice = false
    public var fileName: String?
    public var isLocation = false
    public var isVideoNote = false
    public var quote: MessageQuote?

    public init(messageID: String, authorName: String, isOutgoing: Bool, text: String, photo: MessagePhoto?) {
        self.messageID = messageID
        self.authorName = authorName
        self.isOutgoing = isOutgoing
        self.text = text
        self.photo = photo
    }

    public init(_ message: HistoryMessage) {
        var photo: MessagePhoto?
        if case .photos(let photos, _) = message.content {
            photo = photos.first
        }
        self.init(
            messageID: message.id,
            authorName: message.authorName,
            isOutgoing: message.isOutgoing,
            text: MessageEntity.masked(message.content.text, entities: message.entities),
            photo: photo
        )
        switch message.content {
        case .voice:
            isVoice = true
        case .file(let file, _):
            fileName = file.name
        case .location:
            isLocation = true
        case .videoNote:
            isVideoNote = true
        case .text, .photos, .service, .poll:
            break
        }
    }

    public init(_ message: HistoryMessage, quote: MessageQuote?) {
        self.init(message)
        self.quote = quote
    }
}

public struct MessageQuote: Sendable, Hashable {
    public let text: String
    public let offset: Int

    public init(text: String, offset: Int) {
        self.text = text
        self.offset = offset
    }

    public func range(in text: String) -> NSRange? {
        let string = text as NSString
        let start = min(max(0, offset), string.length)
        let after = string.range(of: self.text, range: NSRange(location: start, length: string.length - start))
        if after.location != NSNotFound {
            return after
        }

        let any = string.range(of: self.text)

        return any.location == NSNotFound ? nil : any
    }

    public func moved(to text: String) -> MessageQuote? {
        range(in: text).map { range in
            MessageQuote(text: self.text, offset: range.location)
        }
    }
}

public struct MessageForward: Sendable, Hashable {
    public let fromID: String
    public let fromName: String

    public init(fromID: String, fromName: String) {
        self.fromID = fromID
        self.fromName = fromName
    }
}

public struct LinkPreview: Sendable, Hashable {
    public let site: String
    public let title: String
    public let summary: String
    public let photo: MessagePhoto?
    public let hasLargePhoto: Bool

    public init(site: String, title: String, summary: String, photo: MessagePhoto?, hasLargePhoto: Bool) {
        self.site = site
        self.title = title
        self.summary = summary
        self.photo = photo
        self.hasLargePhoto = hasLargePhoto
    }
}

public struct MessageLink: Sendable, Hashable {
    public let url: String
    public var preview: LinkPreview?

    public init(url: String, preview: LinkPreview? = nil) {
        self.url = url
        self.preview = preview
    }
}

public struct MessageCommenter: Sendable, Hashable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct MessageComments: Sendable, Hashable {
    public var total: Int
    public var recent: [MessageCommenter]

    public init(total: Int, recent: [MessageCommenter]) {
        self.total = total
        self.recent = recent
    }
}
