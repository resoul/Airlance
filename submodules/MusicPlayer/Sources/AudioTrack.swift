import Foundation

public struct AudioTrack: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case music
        case voice
    }

    public let id: String
    public let groupID: String
    public let url: URL
    public let kind: Kind
    public var title: String
    public var artist: String?

    public init(id: String, groupID: String, url: URL, kind: Kind, title: String, artist: String? = nil) {
        self.id = id
        self.groupID = groupID
        self.url = url
        self.kind = kind
        self.title = title
        self.artist = artist
    }
}

public enum PlaybackOrder: Sendable, Hashable, CaseIterable {
    case regular
    case reversed
    case random

    public var next: PlaybackOrder {
        switch self {
        case .regular:
            .reversed
        case .reversed:
            .random
        case .random:
            .regular
        }
    }
}

public enum PlaybackLooping: Sendable, Hashable, CaseIterable {
    case none
    case all
    case one

    public var next: PlaybackLooping {
        switch self {
        case .none:
            .all
        case .all:
            .one
        case .one:
            .none
        }
    }
}

public enum PlaybackRate: Double, Sendable, Hashable, CaseIterable {
    case normal = 1
    case fast = 1.5
    case faster = 2

    public var next: PlaybackRate {
        switch self {
        case .normal:
            .fast
        case .fast:
            .faster
        case .faster:
            .normal
        }
    }

    public var title: String {
        switch self {
        case .normal:
            "1×"
        case .fast:
            "1.5×"
        case .faster:
            "2×"
        }
    }
}

public struct PlaybackState: Sendable, Equatable {
    public var track: AudioTrack?
    public var isPlaying = false
    public var position: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var rate = PlaybackRate.normal
    public var order = PlaybackOrder.regular
    public var looping = PlaybackLooping.none
    public var hasPrevious = false
    public var hasNext = false

    public init() {}

    public var progress: Double {
        duration > 0 ? min(1, max(0, position / duration)) : 0
    }

    public func isCurrent(_ id: String, in groupID: String) -> Bool {
        track?.id == id && track?.groupID == groupID
    }
}
