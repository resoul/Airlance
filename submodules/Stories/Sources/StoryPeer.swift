import AvatarUI
import UIKit

public struct StoryPeer: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let avatar: AvatarDescriptor
    public let storyCount: Int
    public let unseenCount: Int
    public let isSelf: Bool

    public init(id: String, title: String, avatar: AvatarDescriptor, storyCount: Int, unseenCount: Int, isSelf: Bool) {
        self.id = id
        self.title = title
        self.avatar = avatar
        self.storyCount = storyCount
        self.unseenCount = min(max(unseenCount, 0), storyCount)
        self.isSelf = isSelf
    }

    public var hasUnseen: Bool {
        unseenCount > 0
    }
}

public struct StoriesHeaderTheme: Sendable, Equatable {
    public var background: UIColor
    public var title: UIColor
    public var titleFont: UIFont
    public var name: UIColor
    public var nameFont: UIFont
    public var unseen: UIColor
    public var seen: UIColor

    public init(
        background: UIColor = .systemBackground,
        title: UIColor = .label,
        titleFont: UIFont = .systemFont(ofSize: 17, weight: .semibold),
        name: UIColor = .label,
        nameFont: UIFont = .systemFont(ofSize: 11),
        unseen: UIColor = .systemGreen,
        seen: UIColor = .systemGray3
    ) {
        self.background = background
        self.title = title
        self.titleFont = titleFont
        self.name = name
        self.nameFont = nameFont
        self.unseen = unseen
        self.seen = seen
    }
}
