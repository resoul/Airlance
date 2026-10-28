import Foundation
import Stories
import UIKit

enum StoryPeers {
    static func peer(_ story: StorySummary, strings: AppStrings) -> StoryPeer {
        StoryPeer(
            id: story.peerID,
            title: story.isSelf ? strings.storiesMine : String(story.name.split(separator: " ").first ?? ""),
            avatar: PeerAvatars.descriptor(id: story.peerID, name: story.name),
            storyCount: story.total,
            unseenCount: story.unseen,
            isSelf: story.isSelf
        )
    }

    static func author(_ story: StorySummary, strings: AppStrings, now: Date) -> StoryAuthor {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = strings.pack.locale
        formatter.unitsStyle = .short
        let items = (0..<story.total).map { index in
            let hoursAgo = Double(story.total - index) * 2.5
            let timeText = formatter.localizedString(for: now - hoursAgo * 3600, relativeTo: now)

            return StoryItem(
                id: "\(story.peerID)-\(index)",
                media: media(for: story.peerID, index: index),
                timeText: timeText
            )
        }

        return StoryAuthor(peer: peer(story, strings: strings), items: items)
    }

    private static func media(for peerID: String, index: Int) -> StoryMedia {
        let bundle = Bundle.main
        if peerID == "anna", index == 0, let url = bundle.url(forResource: "avatar-demo-video", withExtension: "mp4") {
            return .video(url)
        }

        if peerID == "boris", index == 0, let url = bundle.url(forResource: "avatar-demo-photo", withExtension: "jpg") {
            return .image { _ in
                UIImage(contentsOfFile: url.path)
            }
        }

        let seed = peerID.unicodeScalars.reduce(index) { sum, scalar in
            sum + Int(scalar.value)
        }

        return .image { size in
            StoryArt.render(seed: seed, size: size)
        }
    }
}
