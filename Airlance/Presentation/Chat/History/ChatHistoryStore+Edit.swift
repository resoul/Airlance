import ChatHistory
import Foundation

extension ChatHistoryStore {
    func edit(_ messageID: String, text: String, in id: String) {
        guard let messages = histories[id]?.messages, let index = messages.firstIndex(where: { message in
            message.id == messageID
        }) else {
            return
        }

        var message = messages[index]
        switch message.content {
        case .text:
            message.content = .text(text)
        case .photos(let photos, _):
            message.content = .photos(photos, caption: text)
        case .file(let file, _):
            message.content = .file(file, caption: text)
        case .voice, .location, .service:
            return
        }
        guard message != messages[index] else {
            return
        }

        message.isEdited = true
        let url = Self.firstLink(in: text)
        let needsPreview = url != nil && url != message.link?.url
        if case .text = message.content, url != message.link?.url {
            message.link = url.map { url in
                MessageLink(url: url)
            }
        }
        histories[id]?.messages[index] = message
        refreshQuotes(of: message, in: id)
        chatsStore.recordEdit(message, in: id)
        changed(id)
        if needsPreview, let url, case .text = message.content {
            loadPreview(url, messageID: message.id, chatID: id)
        }
    }

    @discardableResult
    func postService(_ service: MessageService, in id: String) -> HistoryMessage {
        let message = HistoryMessage(
            id: "\(id)-service-\(UUID().uuidString)",
            authorID: "me",
            authorName: "",
            isOutgoing: true,
            date: Date(),
            content: .service(service)
        )
        histories[id]?.messages.append(message)

        return message
    }

    private func refreshQuotes(of message: HistoryMessage, in id: String) {
        guard let messages = histories[id]?.messages else {
            return
        }

        let quote = MessageReply(message)
        for (index, item) in messages.enumerated() {
            if item.reply?.messageID == message.id {
                histories[id]?.messages[index].reply = quote
            }
            if case .service(.pinned(let reply)) = item.content, reply.messageID == message.id {
                histories[id]?.messages[index].content = .service(.pinned(quote))
            }
        }
    }
}
