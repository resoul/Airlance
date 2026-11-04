import Haptics
import QuartzCore

extension ChatHistoryController {
    func react(_ emoji: String, messageID: String) {
        let wasChosen = message(messageID)?.chosenReaction == emoji
        let limit = store.chatsStore.channelSettings.settings(chatID).reactionsPerPost ?? .max
        let reactions = message(messageID)?.reactions ?? []
        let hasEmoji = reactions.contains { reaction in
            reaction.emoji == emoji
        }
        let fits = hasEmoji || reactions.count < limit
        guard wasChosen || (fits && store.chatsStore.reactionRule(for: chatID).allows(emoji)) else {
            Haptics.play(.warning)

            return
        }

        Haptics.play(.selection)
        store.toggleReaction(emoji, messageID: messageID, in: chatID)
        guard !wasChosen else {
            return
        }

        Task { [weak self] in
            for _ in 0..<4 {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard let node = self?.listView.node(for: messageID) as? MessageBubbleNode else {
                    return
                }

                if node.popReaction(emoji) {
                    return
                }
            }
        }
    }

    func bubbleTapped(_ messageID: String) {
        if let message = message(messageID), message.delivery == .failed, message.isOutgoing,
           let node = listView.node(for: messageID) as? MessageBubbleNode {
            onFailedMessage?(message, node)

            return
        }

        let now = CACurrentMediaTime()
        guard let last = lastBubbleTap, last.id == messageID, now - last.time < 0.35 else {
            lastBubbleTap = (messageID, now)

            return
        }

        lastBubbleTap = nil
        if let emoji = store.chatsStore.reactionRule(for: chatID).doubleTapEmoji(default: Reactions.doubleTap) {
            react(emoji, messageID: messageID)
        }
    }
}
