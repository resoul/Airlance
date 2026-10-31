import Haptics
import QuartzCore

extension ChatHistoryController {
    func react(_ emoji: String, messageID: String) {
        Haptics.play(.selection)
        let wasChosen = message(messageID)?.chosenReaction == emoji
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
        let now = CACurrentMediaTime()
        guard let last = lastBubbleTap, last.id == messageID, now - last.time < 0.35 else {
            lastBubbleTap = (messageID, now)

            return
        }

        lastBubbleTap = nil
        react(Reactions.doubleTap, messageID: messageID)
    }
}
