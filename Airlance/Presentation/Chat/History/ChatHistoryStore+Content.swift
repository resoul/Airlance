import ChatHistory
import Foundation

extension ChatHistoryStore {
    func send(
        _ text: String,
        to id: String,
        replyTo: HistoryMessage? = nil,
        quote: MessageQuote? = nil,
        options: SendOptions = SendOptions()
    ) {
        let url = Self.firstLink(in: text)
        let link = url.map { url in
            MessageLink(url: url)
        }
        let reply = replyTo.map { message in
            MessageReply(message, quote: quote)
        }
        var message = outgoing(.text(text), in: id, reply: reply, link: link)
        message.entities = MessageEntity.valid(options.entities, in: text)
        message.isSilent = options.isSilent
        message.effect = options.effect
        message.lifetime = options.lifetime
        message.expiresAt = options.lifetime.map { lifetime in
            message.date.addingTimeInterval(lifetime)
        }
        post(message, to: id)
        if let url {
            loadPreview(url, messageID: message.id, chatID: id)
        }
    }

    func forward(_ source: HistoryMessage, authorName: String, to id: String) {
        let origin = source.forward ?? MessageForward(fromID: source.authorID, fromName: authorName)
        var link = source.link
        if link?.preview == nil, let url = link?.url {
            link?.preview = ChatLinkFixtures.preview(for: url)
        }
        var message = outgoing(source.content, in: id, reply: nil, link: link)
        message.forward = origin
        post(message, to: id)
    }

    func sendVoice(_ voice: MessageVoice, to id: String, replyTo: HistoryMessage?, quote: MessageQuote? = nil) {
        let reply = replyTo.map { message in
            MessageReply(message, quote: quote)
        }
        post(outgoing(.voice(voice), in: id, reply: reply, link: nil), to: id)
    }

    @discardableResult
    func postContent(
        _ content: MessageContent,
        to id: String,
        reply: MessageReply? = nil,
        isSilent: Bool = false
    ) -> HistoryMessage {
        var message = outgoing(content, in: id, reply: reply, link: nil)
        message.isSilent = isSilent
        post(message, to: id)
        if case .location(let location) = content, location.title == nil {
            geocode(location, messageID: message.id, chatID: id)
        }

        return message
    }
}
