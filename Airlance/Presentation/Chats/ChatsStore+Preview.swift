import ChatHistory

extension ChatsStore {
    static func preview(of message: HistoryMessage) -> String {
        guard message.entities.contains(where: \.isSpoiler), case .text(let text) = message.content else {
            return preview(of: message.content)
        }

        return MessageEntity.masked(text, entities: message.entities)
    }

    static func preview(of content: MessageContent) -> String {
        switch content {
        case .service:
            ""
        case .file(let file, let caption):
            caption.isEmpty ? "📎 \(file.name)" : caption
        case .location(let location):
            location.title.map { title in
                "📍 \(title)"
            } ?? "📍"
        case .contact(let contact):
            "👤 \(contact.name)"
        case .videoNote:
            "🎥"
        case .poll(let poll):
            "📊 \(poll.question)"
        case .voice:
            "🎤"
        case .photos(_, let caption):
            caption.isEmpty ? "📷" : caption
        case .text(let text):
            text
        }
    }
}
