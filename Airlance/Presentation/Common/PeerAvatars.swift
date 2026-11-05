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

    @MainActor private static var remote: [String: RemoteAvatar] = [:]

    static let storyGreen = UIColor(red: 0.34, green: 0.84, blue: 0.45, alpha: 1)

    @MainActor
    static func server(_ id: String) -> RemoteAvatar? {
        remote[id]
    }

    @MainActor
    static func register(_ avatar: RemoteAvatar, for id: String) {
        remote[id] = avatar
    }

    @MainActor
    static func descriptor(id: String, name: String) -> AvatarDescriptor {
        let initials = AvatarDescriptor.initials(from: name)
        if let avatar = remote[id] {
            return avatar.descriptor(id: id, initials: initials)
        }

        switch media[id] {
        case .photo:
            return AvatarDescriptor(id: id, initials: initials, image: image("avatar-demo-photo"))
        case .video:
            return AvatarDescriptor(id: id, initials: initials, image: image("avatar-demo-poster"), video: video())
        case nil:
            return AvatarDescriptor(id: id, initials: initials)
        }
    }

    @MainActor
    static func gallery(id: String, name: String) -> [AvatarDescriptor] {
        guard remote[id] == nil else {
            return [descriptor(id: id, name: name)]
        }

        let initials = AvatarDescriptor.initials(from: name)
        let photos = ["avatar-demo-photo", "avatar-demo-poster"].map { name in
            AvatarDescriptor(id: "\(id).\(name)", initials: initials, image: image(name))
        }

        return [descriptor(id: id, name: name)] + photos
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
