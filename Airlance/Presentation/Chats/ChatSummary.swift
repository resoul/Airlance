import ChatFolders
import Foundation

enum ChatKind: Sendable {
    case person
    case group
    case channel
}

struct ChatSummary: Identifiable, Sendable, Equatable {
    static let outgoingPrefix = "Ти: "

    let id: String
    let name: String
    let kind: ChatKind
    var message: String
    var date: Date
    var unread = 0
    var isMuted = false
    var isPinned = false
    var isArchived = false
    var outgoingRead: Bool?
    var isOnline = false
    var isContact = true
    var draft: String?
    var draftDate: Date?

    var activityDate: Date {
        max(date, draftDate ?? date)
    }
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
