import ChatHistory
import ChatStorage
import Foundation

struct ServerHistory {
    let storage: ChatStorage
    let me: String
    let account: String
}

extension ChatHistoryStore {
    func loadServerHistory(_ chatID: String) async {
        guard let server, !loadedServerChats.contains(chatID) else {
            return
        }

        loadedServerChats.insert(chatID)
        guard var stored = try? await server.storage.messages(in: chatID) else {
            loadedServerChats.remove(chatID)

            return
        }

        if stored.isEmpty, chatsStore.chat(chatID)?.isMember == false, !chatsStore.isJoined(chatID) {
            stored = await serverPreview?(chatID) ?? []
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
        guard let server, let attachments = serverAttachments(of: message) else {
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
            text: message.content.text,
            sentAtMs: Int64(message.date.timeIntervalSince1970 * 1000),
            state: .sending,
            attachments: attachments,
            forwardName: message.forward?.fromName ?? ""
        )
        Task { [weak self] in
            try? await server.storage.addPending(stored)
            self?.serverSender?(stored)
        }
    }

    private func historyMessage(_ stored: StoredMessage) -> HistoryMessage {
        let isAgent = !stored.author.agentName.isEmpty
        let isOutgoing = stored.sender == server?.me && !isAgent
        onServerAuthor?(stored)
        fetchMissingMedia(stored)
        let chatName = chatsStore.chat(stored.chatID)?.name ?? ""
        let personName = stored.author.fullName.isEmpty ? chatName : stored.author.fullName
        let authorName = isAgent ? "🤖 \(stored.author.agentName)" : personName
        var message = HistoryMessage(
            id: isOutgoing ? stored.clientID : "\(stored.sender):\(stored.clientID)",
            authorID: isOutgoing ? "me" : stored.sender,
            authorName: isOutgoing ? "" : authorName,
            isOutgoing: isOutgoing,
            date: Date(timeIntervalSince1970: TimeInterval(stored.sentAtMs) / 1000),
            content: content(of: stored),
            delivery: Self.delivery(of: stored, isOutgoing: isOutgoing)
        )
        if !stored.forwardName.isEmpty {
            message.forward = MessageForward(fromID: "", fromName: stored.forwardName)
        }
        if isAgent, chatsStore.chat(stored.chatID)?.kind == .channel {
            message.signature = authorName
        }

        return message
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
