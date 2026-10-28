import Foundation
import UIKit

public enum StoryMedia: Sendable {
    case image(@Sendable (CGSize) async -> UIImage?)
    case video(URL)
}

public struct StoryItem: Sendable, Identifiable {
    public let id: String
    public let media: StoryMedia
    public let duration: TimeInterval
    public let timeText: String

    public init(id: String, media: StoryMedia, duration: TimeInterval = 5, timeText: String) {
        self.id = id
        self.media = media
        self.duration = max(duration, 1)
        self.timeText = timeText
    }
}

public struct StoryAuthor: Sendable, Identifiable {
    public let peer: StoryPeer
    public let items: [StoryItem]

    public init(peer: StoryPeer, items: [StoryItem]) {
        self.peer = peer
        self.items = items
    }

    public var id: String {
        peer.id
    }

    var startIndex: Int {
        guard peer.hasUnseen else {
            return 0
        }

        return min(max(items.count - peer.unseenCount, 0), max(items.count - 1, 0))
    }
}

@MainActor
public protocol StoryTransitionSource: AnyObject {
    func storyAvatarFrame(for peerID: String) -> CGRect?
}
