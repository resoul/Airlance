import ChatStorage
import Foundation

extension ChatSummary {
    static func server(id: String, name: String) -> ChatSummary {
        ChatSummary(id: id, name: name, kind: .person, message: "", date: Date(timeIntervalSince1970: 0))
    }

    @MainActor
    static func server(_ stored: StoredChat, me: String, contacts: ServerContactsStore?) -> ChatSummary {
        let custom = contacts?.contact(for: stored.peer.subject)?.displayName
        var chat = server(id: stored.id, name: custom ?? stored.peer.fullName)
        chat.unread = stored.unread
        chat.avatarKey = stored.peer.photoMediaID + stored.peer.videoMediaID
        if let last = stored.last {
            chat.message = last.sender == me ? outgoingPrefix + last.text : last.text
            chat.date = Date(timeIntervalSince1970: TimeInterval(last.sentAtMs) / 1000)
        }

        return chat
    }
}
