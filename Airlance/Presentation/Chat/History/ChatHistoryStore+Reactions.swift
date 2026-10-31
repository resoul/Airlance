import ChatHistory

extension ChatHistoryStore {
    func toggleReaction(_ emoji: String, messageID: String, in id: String) {
        update(messageID, in: id) { message in
            message.toggleReaction(emoji, by: Reactions.me)
        }
    }
}
