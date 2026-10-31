import ChatHistory
import Foundation

enum ChatEntityFixtures {
    static func decorate(_ messages: inout [HistoryMessage], chat: ChatSummary) {
        var random = SeededRandom(seed: ChatHistoryFixtures.seed("entities:\(chat.id)"))
        for index in messages.indices {
            guard case .text(let text) = messages[index].content, messages[index].link == nil else {
                continue
            }

            var message = messages[index]
            if random.next() % 100 < 8 {
                addSpoiler(to: &message, text: text, random: &random)
            }
            if chat.kind == .group, !message.isOutgoing, random.next() % 100 < 10 {
                addMention(to: &message, random: &random)
            }
            messages[index] = message
        }
    }

    private static func addSpoiler(to message: inout HistoryMessage, text: String, random: inout SeededRandom) {
        let string = text as NSString
        var words: [NSRange] = []
        let whole = NSRange(location: 0, length: string.length)
        string.enumerateSubstrings(in: whole, options: .byWords) { _, range, _, _ in
            words.append(range)
        }
        guard words.count >= 4 else {
            return
        }

        let count = 1 + Int(random.next() % 3)
        let first = words[words.count - count]
        let last = words[words.count - 1]
        let length = NSMaxRange(last) - first.location
        message.entities.append(MessageEntity(.spoiler, location: first.location, length: length))
    }

    private static func addMention(to message: inout HistoryMessage, random: inout SeededRandom) {
        let people = ChatChannelFixtures.commenters.filter { person in
            person.id != message.authorID
        }
        guard !people.isEmpty, case .text(let text) = message.content else {
            return
        }

        let person = people[Int(random.next() % UInt64(people.count))]
        let mention = "@" + person.name
        let prefix = mention + ", "
        let shift = (prefix as NSString).length
        message.content = .text(prefix + text)
        message.entities = message.entities.map { entity in
            MessageEntity(entity.kind, location: entity.location + shift, length: entity.length)
        }
        let length = (mention as NSString).length
        message.entities.insert(MessageEntity(.mention(userID: person.id), location: 0, length: length), at: 0)
    }
}
