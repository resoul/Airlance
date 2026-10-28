import ChatFolders
import Foundation

enum ChatKind: Sendable {
    case person
    case group
    case channel
}

struct ChatSummary: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let kind: ChatKind
    let message: String
    let date: Date
    var unread = 0
    var isMuted = false
    var isPinned = false
    var outgoingRead: Bool?
    var isOnline = false
    var isContact = true
}

extension ChatSummary: ChatFolderMember {
    var folderChatID: String {
        id
    }

    var folderCategory: ChatFolderCategory {
        switch kind {
        case .person:
            isContact ? .contacts : .nonContacts
        case .group:
            .groups
        case .channel:
            .channels
        }
    }

    var hasUnread: Bool {
        unread > 0
    }
}
