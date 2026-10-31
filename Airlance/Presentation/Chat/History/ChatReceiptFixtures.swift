import ChatHistory
import Foundation

struct MessageReceipts {
    struct Person: Hashable {
        let commenter: MessageCommenter
        let readAt: Date?
        let reaction: String?
    }

    let people: [Person]
    let readAt: Date?

    var readCount: Int {
        people.filter { person in
            person.readAt != nil
        }.count
    }

    var reactionCount: Int {
        people.filter { person in
            person.reaction != nil
        }.count
    }

    var reactionEmojis: [String] {
        var emojis: [String] = []
        for person in people {
            if let emoji = person.reaction, !emojis.contains(emoji) {
                emojis.append(emoji)
            }
        }

        return emojis
    }
}

enum ChatReceiptFixtures {
    static let groupLimit = 100

    static func receipts(for message: HistoryMessage, chat: ChatSummary?) -> MessageReceipts? {
        guard let chat, !message.content.isService else {
            return nil
        }

        switch chat.kind {
        case .person:
            guard message.isOutgoing, message.delivery == .read else {
                return nil
            }

            return MessageReceipts(people: [], readAt: readDate(for: message))
        case .group:
            guard chat.memberCount <= groupLimit else {
                return nil
            }

            let people = groupPeople(for: message, members: chat.memberCount)

            return people.isEmpty ? nil : MessageReceipts(people: people, readAt: nil)
        case .channel:
            return nil
        }
    }

    private static func readDate(for message: HistoryMessage) -> Date {
        var random = SeededRandom(seed: ChatHistoryFixtures.seed("read:\(message.id)"))
        let delay = TimeInterval(20 + random.next() % 3600)

        return min(Date(), message.date.addingTimeInterval(delay))
    }

    private static func groupPeople(for message: HistoryMessage, members: Int) -> [MessageReceipts.Person] {
        var random = SeededRandom(seed: ChatHistoryFixtures.seed("receipts:\(message.id)"))
        var reactions: [String: String] = [:]
        for reaction in message.reactions {
            for person in reactors(of: reaction, random: &random) where person.id != Reactions.me.id {
                reactions[person.id] = reaction.emoji
            }
        }
        let pool = ChatChannelFixtures.commenters.filter { person in
            person.id != message.authorID
        }
        let readers = message.isOutgoing && message.delivery == .read
            ? Int(random.next() % UInt64(min(pool.count, max(1, members - 1)))) + 1
            : 0
        var people: [MessageReceipts.Person] = []
        for (index, person) in pool.enumerated() where index < readers || reactions[person.id] != nil {
            let delay = TimeInterval(30 + random.next() % 5400)
            people.append(MessageReceipts.Person(
                commenter: person,
                readAt: readers > 0 ? min(Date(), message.date.addingTimeInterval(delay)) : nil,
                reaction: reactions[person.id]
            ))
        }

        return people.sorted { lhs, rhs in
            let left = (lhs.reaction != nil ? 1 : 0, lhs.readAt ?? .distantPast)
            let right = (rhs.reaction != nil ? 1 : 0, rhs.readAt ?? .distantPast)

            return left > right
        }
    }

    private static func reactors(of reaction: MessageReaction, random: inout SeededRandom) -> [MessageCommenter] {
        var people = reaction.recent
        let pool = ChatChannelFixtures.commenters
        while people.count < min(reaction.total, pool.count) {
            let person = pool[Int(random.next() % UInt64(pool.count))]
            if !people.contains(person) {
                people.append(person)
            }
        }

        return people
    }
}
