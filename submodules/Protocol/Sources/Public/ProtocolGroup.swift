public enum ServerChatKind: Int32, Sendable, Equatable {
    case direct = 0
    case group = 1
    case channel = 2
}

public enum ServerChatRole: Int32, Sendable, Equatable, Comparable {
    case member = 0
    case admin = 1
    case owner = 2

    public static func < (lhs: ServerChatRole, rhs: ServerChatRole) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ServerChatDetails: Sendable, Equatable {
    public var kind: ServerChatKind
    public var title: String
    public var about: String
    public var link: String
    public var inviteToken: String
    public var memberCount: Int32
    public var role: ServerChatRole
    public var isMember: Bool
    public var isPinned: Bool
    public var isMuted: Bool

    public init(
        kind: ServerChatKind = .direct,
        title: String = "",
        about: String = "",
        link: String = "",
        inviteToken: String = "",
        memberCount: Int32 = 2,
        role: ServerChatRole = .member,
        isMember: Bool = true,
        isPinned: Bool = false,
        isMuted: Bool = false
    ) {
        self.isMuted = isMuted
        self.isPinned = isPinned
        self.kind = kind
        self.title = title
        self.about = about
        self.link = link
        self.inviteToken = inviteToken
        self.memberCount = memberCount
        self.role = role
        self.isMember = isMember
    }
}

public struct ServerMessageAuthor: Sendable, Equatable {
    public let firstName: String
    public let lastName: String
    public let photoMediaID: String
    public let videoMediaID: String
    public let agentName: String

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

public struct ServerChatMember: Sendable, Equatable {
    public let person: SearchPerson
    public let role: ServerChatRole

    public init(person: SearchPerson, role: ServerChatRole) {
        self.person = person
        self.role = role
    }
}

public struct ChatCreateRequest: Sendable, Equatable {
    public let clientID: String
    public let kind: ServerChatKind
    public let title: String
    public let about: String
    public let link: String
    public let members: [String]

    public init(clientID: String, kind: ServerChatKind, title: String, about: String, link: String, members: [String]) {
        self.clientID = clientID
        self.kind = kind
        self.title = title
        self.about = about
        self.link = link
        self.members = members
    }
}

public enum GroupWireMessage: Sendable, Equatable {
    case create(ChatCreateRequest)
    case join(code: String)
    case leave(chatID: String)
    case membersGet(chatID: String)
    case members([ServerChatMember])
    case memberAdd(chatID: String, subject: String, role: ServerChatRole)
    case memberRemove(chatID: String, subject: String)
    case search(query: String)
    case searchResults([ServerChat])
    case resolve(code: String)
    case pinSet(chatID: String, isPinned: Bool)
    case muteSet(chatID: String, isMuted: Bool)
    case inviteReset(chatID: String)
    case userResolve(username: String)
    case changed
}

public struct ServerAttachment: Sendable, Equatable {
    public let kind: Int32
    public let mediaID: String
    public let thumbMediaID: String
    public let name: String
    public let size: Int64
    public let width: Int32
    public let height: Int32
    public let durationMs: Int32
    public let waveform: [UInt8]
    public let title: String
    public let performer: String

    public init(
        kind: Int32,
        mediaID: String,
        thumbMediaID: String,
        name: String,
        size: Int64,
        width: Int32,
        height: Int32,
        durationMs: Int32,
        waveform: [UInt8],
        title: String,
        performer: String
    ) {
        self.kind = kind
        self.mediaID = mediaID
        self.thumbMediaID = thumbMediaID
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
