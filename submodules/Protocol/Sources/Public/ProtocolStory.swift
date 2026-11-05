public enum StoryWireMessage: Sendable, Equatable {
    case publish(StoryPublishRequest)
    case story(ServerStory)
    case feedGet
    case feed([ServerStory])
    case view(storyID: String)
    case delete(storyID: String)
    case changed
}

public struct StoryPublishRequest: Sendable, Equatable {
    public let clientID: String
    public let mediaID: String
    public let coverMediaID: String
    public let isVideo: Bool
    public let lifetimeHours: Int32
    public let meta: String

    public init(
        clientID: String,
        mediaID: String,
        coverMediaID: String,
        isVideo: Bool,
        lifetimeHours: Int32,
        meta: String
    ) {
        self.clientID = clientID
        self.mediaID = mediaID
        self.coverMediaID = coverMediaID
        self.isVideo = isVideo
        self.lifetimeHours = lifetimeHours
        self.meta = meta
    }
}

public struct ServerStory: Sendable, Equatable {
    public let storyID: String
    public let clientID: String
    public let owner: SearchPerson
    public let mediaID: String
    public let coverMediaID: String
    public let isVideo: Bool
    public let meta: String
    public let createdAtUnix: Int64
    public let expiresAtUnix: Int64
    public let isSeen: Bool
    public let viewCount: Int32

    public init(
        storyID: String,
        clientID: String,
        owner: SearchPerson,
        mediaID: String,
        coverMediaID: String,
        isVideo: Bool,
        meta: String,
        createdAtUnix: Int64,
        expiresAtUnix: Int64,
        isSeen: Bool,
        viewCount: Int32
    ) {
        self.storyID = storyID
        self.clientID = clientID
        self.owner = owner
        self.mediaID = mediaID
        self.coverMediaID = coverMediaID
        self.isVideo = isVideo
        self.meta = meta
        self.createdAtUnix = createdAtUnix
        self.expiresAtUnix = expiresAtUnix
        self.isSeen = isSeen
        self.viewCount = viewCount
    }
}
