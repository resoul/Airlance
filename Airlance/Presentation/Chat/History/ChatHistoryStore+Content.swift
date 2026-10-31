import ChatHistory
import Foundation

extension ChatHistoryStore {
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

        return message
    }
}
