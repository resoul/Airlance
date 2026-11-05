public enum StoredMessageState: String, Sendable, Equatable {
    case sending
    case sent
    case failed
}

public enum StoredAttachmentKind: Int, Sendable, Equatable, Codable {
    case photo = 1
    case video = 2
    case voice = 3
    case file = 4
    case music = 5
    case videoNote = 6
}

public struct StoredAttachment: Sendable, Equatable, Codable {
    public var kind: StoredAttachmentKind
    public var mediaID: String
    public var thumbMediaID: String
    public var localKind: String
    public var localName: String
    public var thumbLocalName: String
    public var name: String
    public var size: Int64
    public var width: Int
    public var height: Int
    public var durationMs: Int
    public var waveform: [UInt8]
    public var title: String
    public var performer: String

    public init(
        kind: StoredAttachmentKind,
        mediaID: String = "",
        thumbMediaID: String = "",
        localKind: String = "",
        localName: String = "",
        thumbLocalName: String = "",
        name: String = "",
        size: Int64 = 0,
        width: Int = 0,
        height: Int = 0,
        durationMs: Int = 0,
        waveform: [UInt8] = [],
        title: String = "",
        performer: String = ""
    ) {
        self.kind = kind
        self.mediaID = mediaID
        self.thumbMediaID = thumbMediaID
        self.localKind = localKind
        self.localName = localName
        self.thumbLocalName = thumbLocalName
        self.name = name
        self.size = size
        self.width = width
        self.height = height
        self.durationMs = durationMs
        self.waveform = waveform
        self.title = title
        self.performer = performer
    }
}

public struct StoredMessage: Sendable, Equatable {
    public let chatID: String
    public let sender: String
    public let clientID: String
    public var messageID: Int64?
    public var text: String
    public var sentAtMs: Int64
    public var state: StoredMessageState
    public var author: StoredAuthor
    public var attachments: [StoredAttachment]
    public var forwardName: String

    public init(
        chatID: String,
        sender: String,
        clientID: String,
        messageID: Int64?,
        text: String,
        sentAtMs: Int64,
        state: StoredMessageState,
        author: StoredAuthor = StoredAuthor(),
        attachments: [StoredAttachment] = [],
        forwardName: String = ""
    ) {
        self.author = author
        self.attachments = attachments
        self.forwardName = forwardName
        self.chatID = chatID
        self.sender = sender
        self.clientID = clientID
        self.messageID = messageID
        self.text = text
        self.sentAtMs = sentAtMs
        self.state = state
    }
}

public struct StoredAuthor: Sendable, Equatable {
    public let firstName: String
    public let lastName: String
    public let photoMediaID: String
    public let videoMediaID: String
    public let agentName: String

    public var fullName: String {
        let parts = [firstName, lastName].filter { part in
            !part.isEmpty
        }

        return parts.joined(separator: " ")
    }

    public init(
        firstName: String = "",
        lastName: String = "",
        photoMediaID: String = "",
        videoMediaID: String = "",
        agentName: String = ""
    ) {
        self.agentName = agentName
        self.firstName = firstName
        self.lastName = lastName
        self.photoMediaID = photoMediaID
        self.videoMediaID = videoMediaID
    }
}

public enum StoredChatKind: Int, Sendable, Equatable {
    case direct = 0
    case group = 1
    case channel = 2
}

public struct StoredChatDetails: Sendable, Equatable {
    public var kind: StoredChatKind
    public var title: String
    public var about: String
    public var link: String
    public var inviteToken: String
    public var memberCount: Int
    public var role: Int
    public var isPinned: Bool

    public init(
        kind: StoredChatKind = .direct,
        title: String = "",
        about: String = "",
        link: String = "",
        inviteToken: String = "",
        memberCount: Int = 2,
        role: Int = 0,
        isPinned: Bool = false
    ) {
        self.isPinned = isPinned
        self.kind = kind
        self.title = title
        self.about = about
        self.link = link
        self.inviteToken = inviteToken
        self.memberCount = memberCount
        self.role = role
    }
}

public struct StoredPeer: Sendable, Equatable {
    public let subject: String
    public let firstName: String
    public let lastName: String
    public let username: String
    public let photoMediaID: String
    public let videoMediaID: String

    public var fullName: String {
        let parts = [firstName, lastName].filter { part in
            !part.isEmpty
        }

        return parts.joined(separator: " ")
    }

    public init(
        subject: String,
        firstName: String,
        lastName: String,
        username: String,
        photoMediaID: String = "",
        videoMediaID: String = ""
    ) {
        self.subject = subject
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.photoMediaID = photoMediaID
        self.videoMediaID = videoMediaID
    }
}

public struct StoredChat: Sendable, Equatable {
    public let id: String
    public let peer: StoredPeer
    public let unread: Int
    public let last: StoredMessage?
    public let details: StoredChatDetails
    public let unreadMentions: Int

    public init(
        id: String,
        peer: StoredPeer,
        unread: Int,
        last: StoredMessage?,
        details: StoredChatDetails = StoredChatDetails(),
        unreadMentions: Int = 0
    ) {
        self.unreadMentions = unreadMentions
        self.details = details
        self.id = id
        self.peer = peer
        self.unread = unread
        self.last = last
    }
}

public struct StoredMessagesEvent: Sendable {
    public let chatID: String
    public let messages: [StoredMessage]
}
