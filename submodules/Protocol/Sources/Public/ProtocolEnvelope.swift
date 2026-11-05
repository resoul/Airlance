public struct ProtocolEnvelope: Sendable, Equatable {
    public let seq: UInt64
    public let requestID: UInt64
    public let message: ProtocolMessage

    public init(seq: UInt64 = 0, requestID: UInt64 = 0, message: ProtocolMessage) {
        self.seq = seq
        self.requestID = requestID
        self.message = message
    }
}

public enum ProtocolMessage: Sendable, Equatable {
    case ping(id: Int64)
    case pong(id: Int64)
    case error(ServerError)
    case profileGet
    case profileSet(ProfileFields)
    case profileData(ProfileData)
    case profilePhotoAdd(photoMediaID: String, videoMediaID: String)
    case profilePhotoRemove(photoMediaID: String)
    case authenticate(token: String)
    case authenticated(expiresAtUnix: Int64)
    case updatesSubscribe(afterSeq: UInt64)
    case updatesSubscribed(latestSeq: UInt64)
    case media(MediaMessage)
    case search(SearchMessage)
    case chat(ChatWireMessage)
    case story(StoryWireMessage)
    case contact(ContactWireMessage)
    case privacy(PrivacyWireMessage)
    case unsupported(kind: UInt16)
}

public enum ChatWireMessage: Sendable, Equatable {
    case openDirect(peerSubject: String)
    case chat(ServerChat)
    case send(chatID: String, clientID: String, text: String)
    case message(ServerMessage)
    case historyGet(chatID: String, beforeID: Int64, limit: Int32)
    case history([ServerMessage])
    case chatsGet(beforeID: Int64)
    case chats([ServerChat])
}

public struct ServerMessage: Sendable, Equatable {
    public let chatID: String
    public let messageID: Int64
    public let sender: String
    public let clientID: String
    public let text: String
    public let sentAtUnixMs: Int64

    public init(chatID: String, messageID: Int64, sender: String, clientID: String, text: String, sentAtUnixMs: Int64) {
        self.chatID = chatID
        self.messageID = messageID
        self.sender = sender
        self.clientID = clientID
        self.text = text
        self.sentAtUnixMs = sentAtUnixMs
    }
}

public struct ServerChat: Sendable, Equatable {
    public let chatID: String
    public let peer: SearchPerson
    public let lastMessage: ServerMessage?

    public init(chatID: String, peer: SearchPerson, lastMessage: ServerMessage?) {
        self.chatID = chatID
        self.peer = peer
        self.lastMessage = lastMessage
    }
}

public enum SearchMessage: Sendable, Equatable {
    case query(String)
    case results([SearchPerson])
    case publicProfileGet(subject: String)
}

public struct SearchPerson: Sendable, Equatable {
    public let subject: String
    public let firstName: String
    public let lastName: String
    public let username: String
    public let photoMediaID: String
    public let videoMediaID: String

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

public enum MediaMessage: Sendable, Equatable {
    case uploadRequest(size: Int64)
    case uploadTicket(mediaID: String, url: String, expiresAtUnix: Int64)
    case downloadRequest(mediaID: String)
    case downloadTicket(url: String, expiresAtUnix: Int64)
}

public struct ProfileFields: Sendable, Equatable {
    public let firstName: String
    public let lastName: String
    public let username: String
    public let bio: String
    public let phone: String
    public let photoMediaID: String
    public let videoMediaID: String

    public init(
        firstName: String,
        lastName: String,
        username: String,
        bio: String,
        phone: String = "",
        photoMediaID: String = "",
        videoMediaID: String = ""
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.bio = bio
        self.phone = phone
        self.photoMediaID = photoMediaID
        self.videoMediaID = videoMediaID
    }
}

public struct ProfilePhotoData: Sendable, Equatable {
    public let photoMediaID: String
    public let videoMediaID: String
    public let addedAtUnix: Int64

    public init(photoMediaID: String, videoMediaID: String, addedAtUnix: Int64) {
        self.photoMediaID = photoMediaID
        self.videoMediaID = videoMediaID
        self.addedAtUnix = addedAtUnix
    }
}

public struct ProfileData: Sendable, Equatable {
    public let subject: String
    public let fields: ProfileFields
    public let photos: [ProfilePhotoData]
    public let updatedAtUnix: Int64

    public init(subject: String, fields: ProfileFields, photos: [ProfilePhotoData] = [], updatedAtUnix: Int64) {
        self.subject = subject
        self.fields = fields
        self.photos = photos
        self.updatedAtUnix = updatedAtUnix
    }
}

public struct ServerError: Sendable, Equatable {
    public let code: Int32
    public let message: String

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }
}
