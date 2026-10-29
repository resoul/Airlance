import ChatHistory
import Foundation

enum ChatServiceFixtures {
    static func decorate(
        _ messages: inout [HistoryMessage],
        chat: ChatSummary,
        pinnedIDs: [String],
        random: inout SeededRandom
    ) {
        markEdited(&messages, random: &random)
        var services: [Int: [MessageService]] = [:]
        if chat.kind == .group {
            services[0, default: []].append(.created(title: chat.name))
            for index in firstMessages(in: messages).dropFirst() {
                services[index, default: []].append(.joined(name: messages[index].authorName))
            }
        }
        for id in pinnedIDs {
            guard let index = messages.firstIndex(where: { message in
                message.id == id
            }) else {
                continue
            }

            let position = min(messages.count - 1, index + 1 + Int(random.next() % 3))
            services[position, default: []].append(.pinned(MessageReply(messages[index])))
        }
        messages = insert(services, into: messages, chatID: chat.id)
    }

    private static func markEdited(_ messages: inout [HistoryMessage], random: inout SeededRandom) {
        for index in messages.indices where !messages[index].content.text.isEmpty {
            if random.next() % 100 < 6 {
                messages[index].isEdited = true
            }
        }
    }

    private static func firstMessages(in messages: [HistoryMessage]) -> [Int] {
        var seen: Set<String> = []
        var result: [Int] = []
        for (index, message) in messages.enumerated() where !message.isOutgoing {
            if seen.insert(message.authorID).inserted {
                result.append(index)
            }
        }

        return result
    }

    private static func insert(
        _ services: [Int: [MessageService]],
        into messages: [HistoryMessage],
        chatID: String
    ) -> [HistoryMessage] {
        var result: [HistoryMessage] = []
        result.reserveCapacity(messages.count + services.count)
        var count = 0
        for (index, message) in messages.enumerated() {
            for service in services[index] ?? [] {
                count += 1
                result.append(HistoryMessage(
                    id: "\(chatID)-service-\(count)",
                    authorID: "service",
                    authorName: "",
                    isOutgoing: false,
                    date: message.date.addingTimeInterval(-1),
                    content: .service(service)
                ))
            }
            result.append(message)
        }

        return result
    }
}
