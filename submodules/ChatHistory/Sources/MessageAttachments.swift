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
            text: message.content.text,
            photo: photo
        )
        switch message.content {
        case .voice:
            isVoice = true
        case .file(let file, _):
            fileName = file.name
        case .location:
            isLocation = true
        case .text, .photos, .service:
            break
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
