import AvatarUI
import Foundation
import ListUI
import UIKit

enum PeerAvatars {
    private enum Media {
        case photo
        case video
    }

    private static let media: [String: Media] = [
        "anna": .video,
        "boris": .photo,
        "me": .video,
    ]

    static let storyGreen = UIColor(red: 0.34, green: 0.84, blue: 0.45, alpha: 1)

    static func descriptor(id: String, name: String) -> AvatarDescriptor {
        let initials = AvatarDescriptor.initials(from: name)
        switch media[id] {
        case .photo:
            return AvatarDescriptor(id: id, initials: initials, image: image("avatar-demo-photo"))
        case .video:
            return AvatarDescriptor(id: id, initials: initials, image: image("avatar-demo-poster"), video: video())
        case nil:
            return AvatarDescriptor(id: id, initials: initials)
        }
    }

    static func storyRing(for story: StorySummary?, theme: ListTheme) -> AvatarStoryRing? {
        guard let story, !story.isSelf else {
            return nil
        }

        let seen = theme.secondary.withAlphaComponent(0.45)

        return AvatarStoryRing(
            totalCount: story.total,
            unseenCount: story.unseen,
            unseenColors: [storyGreen, theme.accent],
            seenColors: [seen, seen]
        )
    }

    private static func image(_ name: String) -> AvatarImage? {
        Bundle.main.url(forResource: name, withExtension: "jpg").map { url in
            AvatarImage(key: name, url: url)
        }
    }

    private static func video() -> AvatarVideo? {
        guard let url = Bundle.main.url(forResource: "avatar-demo-video", withExtension: "mp4") else {
            return nil
        }

        let thumbnail = Bundle.main.url(forResource: "avatar-demo-video-small", withExtension: "mp4")

        return AvatarVideo(key: "avatar-demo-video", url: url, thumbnailURL: thumbnail)
    }
}
