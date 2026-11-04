import Foundation
import MediaStore

public struct MessageVideo: Sendable, Hashable {
    public let source: MediaSource
    public let duration: TimeInterval

    public init(source: MediaSource, duration: TimeInterval) {
        self.source = source
        self.duration = duration
    }
}

public struct MessagePhoto: Sendable, Hashable {
    public let id: String
    public let width: Int
    public let height: Int
    public let source: MediaSource
    public let video: MessageVideo?
    public var size: Int64
    public var isDownloaded: Bool

    public init(
        id: String,
        width: Int,
        height: Int,
        source: MediaSource,
        video: MessageVideo? = nil,
        size: Int64 = 0,
        isDownloaded: Bool = true
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.source = source
        self.video = video
        self.size = size
        self.isDownloaded = isDownloaded
    }

    public var aspectRatio: Double {
        height > 0 ? Double(width) / Double(height) : 1
    }
}

public struct MessageVoice: Sendable, Hashable {
    public let source: MediaSource
    public let duration: TimeInterval
    public let waveform: [UInt8]

    public init(source: MediaSource, duration: TimeInterval, waveform: [UInt8]) {
        self.source = source
        self.duration = duration
        self.waveform = waveform
    }
}

public enum MessageContent: Sendable, Hashable {
    case text(String)
    case photos([MessagePhoto], caption: String)
    case voice(MessageVoice)
    case file(MessageFile, caption: String)
    case location(MessageLocation)
    case service(MessageService)
    case poll(MessagePoll)
    case videoNote(MessageVideoNote)
    case contact(MessageContact)

    public var text: String {
        switch self {
        case .text(let text):
            text
        case .photos(_, let caption), .file(_, let caption):
            caption
        case .poll(let poll):
            poll.question
        case .contact(let contact):
            contact.name
        case .voice, .location, .service, .videoNote:
            ""
        }
    }

    public var isService: Bool {
        guard case .service = self else {
            return false
        }

        return true
    }

    public var isEditable: Bool {
        switch self {
        case .text, .photos, .file:
            true
        case .voice, .location, .service, .poll, .videoNote, .contact:
            false
        }
    }
}

public enum DeliveryState: Sendable, Hashable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

public struct HistoryMessage: Identifiable, Sendable, Hashable {
    public let id: String
    public let authorID: String
    public let authorName: String
    public let isOutgoing: Bool
    public var date: Date
    public var content: MessageContent
    public var delivery: DeliveryState
    public var isListened = true
    public var isEdited = false
    public var reply: MessageReply?
    public var forward: MessageForward?
    public var link: MessageLink?
    public var views: Int?
    public var signature: String?
    public var comments: MessageComments?
    public var reactions: [MessageReaction] = []
    public var entities: [MessageEntity] = []
    public var isSilent = false
    public var videoReactions: [MessageVideoReaction] = []
    public var effect: String?
    public var lifetime: TimeInterval?
    public var expiresAt: Date?

    public init(
        id: String,
        authorID: String,
        authorName: String,
        isOutgoing: Bool,
        date: Date,
        content: MessageContent,
        delivery: DeliveryState = .read,
        reply: MessageReply? = nil,
        forward: MessageForward? = nil,
        link: MessageLink? = nil
    ) {
        self.id = id
        self.authorID = authorID
        self.authorName = authorName
        self.isOutgoing = isOutgoing
        self.date = date
        self.content = content
        self.delivery = delivery
        self.reply = reply
        self.forward = forward
        self.link = link
    }
}
