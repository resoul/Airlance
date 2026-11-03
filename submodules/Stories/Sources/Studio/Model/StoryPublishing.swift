import Foundation

public enum StoryLifetime: Int, CaseIterable, Codable, Sendable {
    case hours6 = 6
    case hours12 = 12
    case hours24 = 24
    case hours48 = 48

    public var interval: TimeInterval {
        TimeInterval(rawValue) * 3600
    }
}

public struct StoryPublishSettings: Codable, Hashable, Sendable {
    public var lifetime = StoryLifetime.hours24
    public var isPinned = false
    public var isProtected = false
    public var caption = ""
    public var excluded: [StoryMentionPeer] = []
    public var selected: [StoryMentionPeer] = []

    public init() {
    }
}
