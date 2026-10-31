import ChatHistory
import Foundation

enum Reactions {
    static let quick = ["❤️", "👍", "🔥", "😂", "😮", "😢", "🎉"]
    static let doubleTap = "❤️"
    static let more = [
        "😁", "🙏", "👏", "🤯", "🥰", "😍", "🤩", "😎",
        "🤔", "😱", "🥳", "😭", "🤝", "💯", "⚡", "🙈",
        "😇", "🤗", "👀", "💔", "🤡", "🏆", "🍾", "🌚",
        "🥱", "🤓", "✍️", "💅", "🫡", "🦄", "🐳", "🍓",
    ]

    static var me: MessageCommenter {
        MessageCommenter(id: "me", name: ProfileFixture.current.name)
    }
}

enum ChatReactionFixtures {
    static func decorate(_ messages: inout [HistoryMessage], chat: ChatSummary, random: inout SeededRandom) {
        ChatChannelFixtures.decorate(&messages, chat: chat, random: &random)
        ChatEntityFixtures.decorate(&messages, chat: chat)
        ChatPollFixtures.decorate(&messages, chat: chat)
        ChatVideoNoteFixtures.decorate(&messages, chat: chat)
        for index in messages.indices where !messages[index].content.isService {
            switch chat.kind {
            case .person:
                messages[index].reactions = personal(messages[index], chat: chat, random: &random)
            case .group:
                messages[index].reactions = group(random: &random)
            case .channel:
                messages[index].reactions = channel(views: messages[index].views ?? 0, random: &random)
            }
        }
    }

    private static func personal(
        _ message: HistoryMessage,
        chat: ChatSummary,
        random: inout SeededRandom
    ) -> [MessageReaction] {
        guard random.next() % 100 < 12 else {
            return []
        }

        let emoji = pick(&random)
        guard message.isOutgoing else {
            return [MessageReaction(emoji: emoji, total: 1, isChosen: true, recent: [Reactions.me])]
        }

        let other = MessageCommenter(id: chat.id, name: chat.name)

        return [MessageReaction(emoji: emoji, total: 1, isChosen: false, recent: [other])]
    }

    private static func group(random: inout SeededRandom) -> [MessageReaction] {
        guard random.next() % 100 < 18 else {
            return []
        }

        let kinds = 1 + Int(random.next() % 2)
        var reactions: [MessageReaction] = []
        for kind in 0..<kinds {
            let emoji = pick(&random)
            guard !reactions.contains(where: { reaction in
                reaction.emoji == emoji
            }) else {
                continue
            }

            let total = 1 + Int(random.next() % 4)
            let isChosen = kind == 0 && random.next() % 10 < 3
            var recent = people(total - (isChosen ? 1 : 0), random: &random)
            if isChosen {
                recent.insert(Reactions.me, at: 0)
            }
            reactions.append(MessageReaction(emoji: emoji, total: total, isChosen: isChosen, recent: recent))
        }

        return reactions
    }

    private static func channel(views: Int, random: inout SeededRandom) -> [MessageReaction] {
        guard views > 0, random.next() % 100 < 75 else {
            return []
        }

        let kinds = 2 + Int(random.next() % 3)
        var budget = max(kinds, views * (1 + Int(random.next() % 4)) / 100)
        var reactions: [MessageReaction] = []
        let chosen = random.next() % 10 < 2 ? Int(random.next() % UInt64(kinds)) : -1
        for (index, emoji) in Reactions.quick.shuffledPrefix(kinds, random: &random).enumerated() {
            let total = max(1, budget / 2 + Int(random.next() % UInt64(max(1, budget / 4))))
            budget = max(1, budget - total)
            reactions.append(MessageReaction(emoji: emoji, total: total, isChosen: index == chosen))
        }

        return reactions
    }

    private static func pick(_ random: inout SeededRandom) -> String {
        Reactions.quick[Int(random.next() % UInt64(Reactions.quick.count))]
    }

    private static func people(_ count: Int, random: inout SeededRandom) -> [MessageCommenter] {
        let pool = ChatChannelFixtures.commenters
        var picked: [MessageCommenter] = []
        while picked.count < min(3, max(0, count)) {
            let person = pool[Int(random.next() % UInt64(pool.count))]
            if !picked.contains(person) {
                picked.append(person)
            }
        }

        return picked
    }
}

private extension Array where Element == String {
    func shuffledPrefix(_ count: Int, random: inout SeededRandom) -> [String] {
        var pool = self
        var result: [String] = []
        while result.count < count, !pool.isEmpty {
            result.append(pool.remove(at: Int(random.next() % UInt64(pool.count))))
        }

        return result
    }
}
