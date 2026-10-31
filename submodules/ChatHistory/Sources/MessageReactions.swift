import Foundation

public struct MessageReaction: Sendable, Hashable {
    public let emoji: String
    public var total: Int
    public var isChosen: Bool
    public var recent: [MessageCommenter]

    public init(emoji: String, total: Int, isChosen: Bool, recent: [MessageCommenter] = []) {
        self.emoji = emoji
        self.total = total
        self.isChosen = isChosen
        self.recent = recent
    }
}

extension HistoryMessage {
    public var chosenReaction: String? {
        reactions.first { reaction in
            reaction.isChosen
        }?.emoji
    }

    public mutating func toggleReaction(_ emoji: String, by me: MessageCommenter) {
        let previous = chosenReaction
        removeReaction(by: me)
        guard previous != emoji else {
            return
        }

        if let index = reactions.firstIndex(where: { reaction in
            reaction.emoji == emoji
        }) {
            reactions[index].total += 1
            reactions[index].isChosen = true
            reactions[index].recent = Array(([me] + reactions[index].recent).prefix(3))
        } else {
            reactions.append(MessageReaction(emoji: emoji, total: 1, isChosen: true, recent: [me]))
        }
    }

    private mutating func removeReaction(by me: MessageCommenter) {
        guard let index = reactions.firstIndex(where: { reaction in
            reaction.isChosen
        }) else {
            return
        }

        reactions[index].total -= 1
        reactions[index].isChosen = false
        reactions[index].recent.removeAll { commenter in
            commenter.id == me.id
        }
        if reactions[index].total <= 0 {
            reactions.remove(at: index)
        }
    }
}
