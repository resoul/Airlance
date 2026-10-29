import Foundation

public enum MessageService: Sendable, Hashable {
    case created(title: String)
    case joined(name: String)
    case renamed(title: String)
    case pinned(MessageReply)

    public var targetID: String? {
        guard case .pinned(let reply) = self else {
            return nil
        }

        return reply.messageID
    }
}
