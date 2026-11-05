import ChatStorage
import Foundation
import Protocol

extension ChatSummary {
    static func server(id: String, name: String) -> ChatSummary {
        var chat = ChatSummary(id: id, name: name, kind: .person, message: "", date: Date(timeIntervalSince1970: 0))
        chat.isServer = true

        return chat
    }

    @MainActor
    static func server(
        _ stored: StoredChat,
        me: String,
        contacts: ServerContactsStore?,
        thumbnail: @MainActor (StoredAttachment) -> ChatRowThumbnail?
    ) -> ChatSummary {
        let custom = contacts?.contact(for: stored.peer.subject)?.displayName
        let details = stored.details
        var chat = ChatSummary(
            id: stored.id,
            name: details.kind == .direct ? custom ?? stored.peer.fullName : details.title,
            kind: kind(of: details.kind),
            message: "",
            date: Date(timeIntervalSince1970: 0)
        )
        chat.isServer = true
        chat.isPinned = details.isPinned
        chat.unread = stored.unread
        chat.unreadMentions = stored.unreadMentions
        chat.avatarKey = stored.peer.photoMediaID + stored.peer.videoMediaID
        chat.memberCount = details.memberCount
        chat.canPost = details.kind != .channel || details.role > 0
        chat.isPublic = !details.link.isEmpty
        chat.about = details.about
        chat.link = details.link
        chat.joinCode = details.link
        chat.inviteToken = details.inviteToken
        chat.isAdmin = details.role > 0
        if let last = stored.last {
            apply(last, to: &chat, kind: details.kind, me: me, thumbnail: thumbnail)
        }

        return chat
    }

    static func preview(of found: ServerChat, code: String? = nil) -> ChatSummary {
        var chat = ChatSummary(
            id: found.chatID,
            name: found.details.title,
            kind: found.details.kind == .channel ? .channel : .group,
            message: "",
            date: Date(timeIntervalSince1970: 0)
        )
        chat.isServer = true
        chat.isMember = found.details.isMember
        chat.memberCount = Int(found.details.memberCount)
        chat.canPost = found.details.isMember && found.details.role > .member
        chat.isPublic = !found.details.link.isEmpty
        chat.joinCode = code ?? found.details.link
        chat.inviteToken = found.details.inviteToken
        chat.isAdmin = found.details.role > .member
        chat.about = found.details.about
        chat.link = found.details.link

        return chat
    }

    private static func kind(of kind: StoredChatKind) -> ChatKind {
        switch kind {
        case .direct:
            .person
        case .group:
            .group
        case .channel:
            .channel
        }
    }

    @MainActor
    private static func apply(
        _ last: StoredMessage,
        to chat: inout ChatSummary,
        kind: StoredChatKind,
        me: String,
        thumbnail: @MainActor (StoredAttachment) -> ChatRowThumbnail?
    ) {
        let isAgent = !last.author.agentName.isEmpty
        let isOutgoing = last.sender == me && !isAgent
        chat.date = Date(timeIntervalSince1970: TimeInterval(last.sentAtMs) / 1000)
        chat.message = last.text
        chat.preview = rowPreview(of: last, isAgent: isAgent, thumbnail: thumbnail)
        chat.isLastOutgoing = isOutgoing
        chat.lastAuthor = kind == .group && !isOutgoing && !last.author.fullName.isEmpty ? last.author.fullName : nil
        guard isOutgoing else {
            return
        }

        chat.outgoingRead = last.state == .sent ? false : nil
        chat.isSending = last.state == .sending
        chat.isFailed = last.state == .failed
    }

    @MainActor
    private static func rowPreview(
        of last: StoredMessage,
        isAgent: Bool,
        thumbnail: @MainActor (StoredAttachment) -> ChatRowThumbnail?
    ) -> ChatRowPreview {
        let text = isAgent ? "🤖 \(last.text)" : last.text
        guard let first = last.attachments.first else {
            return ChatRowPreview(kind: .text(text), isForwarded: !last.forwardName.isEmpty)
        }

        let kind: ChatRowPreview.Kind
        switch first.kind {
        case .photo:
            kind = .photo
        case .video:
            kind = .video
        case .voice:
            kind = .voice
        case .videoNote:
            kind = .videoNote
        case .file:
            kind = .file(first.name)
        case .music:
            kind = .music(musicTitle(first))
        }

        return ChatRowPreview(
            kind: kind,
            caption: text,
            thumbnails: last.attachments.prefix(ChatRowPreview.maxThumbnails).compactMap { item in
                thumbnail(item)
            },
            isForwarded: !last.forwardName.isEmpty
        )
    }

    private static func musicTitle(_ item: StoredAttachment) -> String {
        if item.performer.isEmpty, item.title.isEmpty {
            return (item.name as NSString).deletingPathExtension
        }

        let parts = [item.performer, item.title].filter { part in
            !part.isEmpty
        }

        return parts.joined(separator: " — ")
    }
}
