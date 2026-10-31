import ChatHistory
import Foundation
import MediaStore

enum ChatVideoNoteFixtures {
    private static let styles: [MessageVideoNote.Style] = [.blob, .moment, .dualCamera, .anonymous]
    private static let clips = ["message-video-square", "message-video-portrait", "message-video-landscape"]

    static func decorate(_ messages: inout [HistoryMessage], chat: ChatSummary) {
        guard chat.kind != .channel, messages.count > 10 else {
            return
        }

        var random = SeededRandom(seed: ChatHistoryFixtures.seed("videonotes:\(chat.id)"))
        let start = messages.count - 9
        for offset in 0..<styles.count {
            let index = start + offset * 2
            guard messages.indices.contains(index), case .text = messages[index].content,
                  messages[index].reply == nil, messages[index].link == nil else {
                continue
            }

            messages[index].content = .videoNote(note(styles[offset], random: &random))
            messages[index].entities = []
        }
        if let target = messages.indices.last(where: { index in
            !messages[index].content.isService && index < messages.count - 1
        }) {
            messages[target].videoReactions = reactions(random: &random)
        }
    }

    private static func note(_ style: MessageVideoNote.Style, random: inout SeededRandom) -> MessageVideoNote {
        let clip = clips[Int(random.next() % UInt64(clips.count))]
        let front = style == .dualCamera ? MediaSource.bundle(name: clips[0], ext: "mp4") : nil
        let levels = (0..<64).map { _ in
            UInt8(40 + random.next() % 200)
        }

        return MessageVideoNote(
            source: .bundle(name: clip, ext: "mp4"),
            frontSource: front,
            duration: 5,
            style: style,
            levels: levels
        )
    }

    private static func reactions(random: inout SeededRandom) -> [MessageVideoReaction] {
        ChatChannelFixtures.commenters.prefix(2).enumerated().map { index, person in
            let note = MessageVideoNote(
                source: .bundle(name: clips[index % clips.count], ext: "mp4"),
                duration: 5,
                style: .reaction
            )

            return MessageVideoReaction(id: "fixture-\(index)-\(random.next() % 1000)", author: person, note: note)
        }
    }
}
