import ChatFolders
import Foundation

enum ChatKind: Sendable {
    case person
    case group
    case channel
}

struct ChatSummary: Identifiable, Sendable, Equatable {
    let id: String
    var name: String
    let kind: ChatKind
    var message: String
    var date: Date
    var avatarKey = ""
    var unread = 0
    var isMuted = false
    var isPinned = false
    var isArchived = false
    var outgoingRead: Bool?
    var isOnline = false
    var isContact = true
    var draft: String?
    var draftDate: Date?
    var memberCount = 0
    var typing: String?
    var canPost = true
    var isPublic = false
    var isServer = false
    var isMember = true
    var about = ""
    var link = ""
    var joinCode = ""
    var inviteToken = ""
    var preview: ChatRowPreview?
    var lastAuthor: String?
    var isLastOutgoing = false
    var isSending = false
    var isFailed = false
    var unreadMentions = 0
    var unreadReactions = 0
    var isAdmin = false

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
