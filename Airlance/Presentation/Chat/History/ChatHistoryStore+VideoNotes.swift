import ChatHistory
import Foundation

extension ChatHistoryStore {
    func addVideoReaction(_ note: MessageVideoNote, to messageID: String, in id: String) {
        update(messageID, in: id) { message in
            let reaction = MessageVideoReaction(id: UUID().uuidString, author: Reactions.me, note: note)
            message.videoReactions.append(reaction)
        }
    }

    func videoReaction(_ reactionID: String, messageID: String, in id: String) -> MessageVideoReaction? {
        let message = history(for: id)?.messages.first { message in
            message.id == messageID
        }

        return message?.videoReactions.first { reaction in
            reaction.id == reactionID
        }
    }
}
