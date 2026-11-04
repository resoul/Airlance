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
    case authenticate(token: String)
    case authenticated(expiresAtUnix: Int64)
    case unsupported(kind: UInt16)
}

public struct ProfileFields: Sendable, Equatable {
    public let firstName: String
    public let lastName: String
    public let username: String
    public let bio: String

    public init(firstName: String, lastName: String, username: String, bio: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.bio = bio
    }
}

public struct ProfileData: Sendable, Equatable {
    public let subject: String
    public let fields: ProfileFields
    public let updatedAtUnix: Int64

    public init(subject: String, fields: ProfileFields, updatedAtUnix: Int64) {
        self.subject = subject
        self.fields = fields
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
