public enum StoredMessageState: String, Sendable, Equatable {
    case sending
    case sent
    case failed
}

public struct StoredMessage: Sendable, Equatable {
    public let chatID: String
    public let sender: String
    public let clientID: String
    public var messageID: Int64?
    public var text: String
    public var sentAtMs: Int64
    public var state: StoredMessageState

    public init(
        chatID: String,
        sender: String,
        clientID: String,
        messageID: Int64?,
        text: String,
        sentAtMs: Int64,
        state: StoredMessageState
    ) {
        self.chatID = chatID
        self.sender = sender
        self.clientID = clientID
        self.messageID = messageID
        self.text = text
        self.sentAtMs = sentAtMs
        self.state = state
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

    public init(id: String, peer: StoredPeer, unread: Int, last: StoredMessage?) {
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
