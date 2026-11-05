import ChatHistory
import ChatStorage
import Foundation

struct ServerHistory {
    let storage: ChatStorage
    let me: String
}

extension ChatHistoryStore {
    func loadServerHistory(_ chatID: String) async {
        guard let server, !loadedServerChats.contains(chatID) else {
            return
        }

        loadedServerChats.insert(chatID)
        guard let stored = try? await server.storage.messages(in: chatID) else {
            loadedServerChats.remove(chatID)

            return
        }

        let known = Set(histories[chatID]?.messages.map(\.id) ?? [])
        let loaded = stored.map(historyMessage).filter { message in
            !known.contains(message.id)
        }
        let kept = histories[chatID]?.messages ?? []
        histories[chatID] = ChatHistoryFixtures.History(messages: loaded + kept, unreadFrom: nil)
    }

    func ingest(_ event: StoredMessagesEvent) {
        guard histories[event.chatID] != nil else {
            return
        }

        for stored in event.messages {
            let message = historyMessage(stored)
            let isKnown = histories[event.chatID]?.messages.contains { current in
                current.id == message.id
            } ?? false
            if isKnown {
                update(message.id, in: event.chatID) { current in
                    current.delivery = message.delivery
                    current.date = message.date
                }
            } else {
                append(message, to: event.chatID)
            }
        }
    }

    func deliverToServer(_ message: HistoryMessage, in id: String) {
        guard let server, case .text(let text) = message.content else {
            update(message.id, in: id) { current in
                current.delivery = .failed
            }

            return
        }

        let stored = StoredMessage(
            chatID: id,
            sender: server.me,
            clientID: message.id,
            messageID: nil,
            text: text,
            sentAtMs: Int64(message.date.timeIntervalSince1970 * 1000),
            state: .sending
        )
        Task { [weak self] in
            try? await server.storage.addPending(stored)
            self?.serverSender?(stored)
        }
    }

    private func historyMessage(_ stored: StoredMessage) -> HistoryMessage {
        let isOutgoing = stored.sender == server?.me

        return HistoryMessage(
            id: isOutgoing ? stored.clientID : "\(stored.sender):\(stored.clientID)",
            authorID: isOutgoing ? "me" : stored.sender,
            authorName: isOutgoing ? "" : chatsStore.chat(stored.chatID)?.name ?? "",
            isOutgoing: isOutgoing,
            date: Date(timeIntervalSince1970: TimeInterval(stored.sentAtMs) / 1000),
            content: .text(stored.text),
            delivery: Self.delivery(of: stored, isOutgoing: isOutgoing)
        )
    }

    private static func delivery(of stored: StoredMessage, isOutgoing: Bool) -> DeliveryState {
        guard isOutgoing else {
            return .read
        }

        switch stored.state {
        case .sending:
            return .sending
        case .sent:
            return .sent
        case .failed:
            return .failed
        }
    }
}
