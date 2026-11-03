import Foundation

public struct StoryTrack: Codable, Hashable, Sendable {
    public var url: URL
    public var title: String
    public var artist: String?
    public var duration: TimeInterval
    public var start: TimeInterval = 0
    public var volume: Float = 1

    public init(url: URL, title: String, artist: String?, duration: TimeInterval) {
        self.url = url
        self.title = title
        self.artist = artist
        self.duration = duration
    }
}

public struct StoryVoice: Codable, Hashable, Sendable {
    public var url: URL
    public var duration: TimeInterval
    public var volume: Float = 1

    public init(url: URL, duration: TimeInterval) {
        self.url = url
        self.duration = duration
    }
}

public struct StorySound: Codable, Hashable, Sendable {
    public static let photoDuration: TimeInterval = 15

    public var track: StoryTrack?
    public var voice: StoryVoice?
    public var originalVolume: Float = 1

    public init() {
    }

    public var hasAudio: Bool {
        track != nil || voice != nil
    }

    public var isIdentity: Bool {
        !hasAudio && originalVolume == 1
    }
}
