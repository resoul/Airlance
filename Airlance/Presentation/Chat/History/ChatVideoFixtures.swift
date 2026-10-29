import ChatHistory
import Foundation

enum ChatVideoFixtures {
    private struct Clip {
        let name: String
        let width: Int
        let height: Int
        let duration: TimeInterval
    }

    private static let clips = [
        Clip(name: "message-video-landscape", width: 960, height: 540, duration: 8),
        Clip(name: "message-video-portrait", width: 540, height: 960, duration: 6),
        Clip(name: "message-video-square", width: 640, height: 640, duration: 5),
    ]

    static func video(id: String, pick: Int) -> MessagePhoto {
        let clip = clips[pick % clips.count]
        let source = "bundle-video:\(clip.name)"

        return MessagePhoto(
            id: id,
            width: clip.width,
            height: clip.height,
            source: source,
            video: MessageVideo(source: source, duration: clip.duration)
        )
    }
}
