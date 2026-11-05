import ChatHistory
import Foundation
import Observers

@MainActor
final class ChatsStore {
    private(set) var chats: [ChatSummary]

    private let observers = ObserverList<[ChatSummary]>()
    private var previews: [String: ChatSummary]
    let channelSettings: ChannelSettingsStore
    private var reportedPosts: Set<String> = []
    private var reportedChannels: Set<String> = []

    init(chats: [ChatSummary], previews: [ChatSummary] = [], channelSettings: ChannelSettingsStore) {
        self.channelSettings = channelSettings
        self.chats = chats.map { chat in
            let settings = channelSettings.settings(chat.id)
            var chat = chat
            chat.name = settings.name ?? chat.name
            if let isPrivate = settings.isPrivate {
                chat.isPublic = !isPrivate
            }

            return chat
        }
        self.previews = Dictionary(uniqueKeysWithValues: previews.map { chat in
            (chat.id, chat)
        })
    }

    func setServerChats(_ next: [ChatSummary], empty: [ChatSummary]) {
        let merged = next.map { chat in
            var chat = chat
            if let current = self.chats.first(where: { current in
                current.id == chat.id
            }) {
                chat.isMuted = current.isMuted
                chat.isPinned = current.isPinned
                chat.isArchived = current.isArchived
                chat.draft = current.draft
                chat.draftDate = current.draftDate
            }

            return chat
        }
        chats = merged.sorted { left, right in
            left.date > right.date
        }
        for chat in empty {
            previews[chat.id] = chat
        }
        observers.notify(chats)
    }

    func addServerPreview(_ chat: ChatSummary) {
        previews[chat.id] = chat
    }

    func chat(_ id: String) -> ChatSummary? {
        chats.first { chat in
            chat.id == id
        } ?? previews[id]
    }

    func reactionRule(for id: String) -> ChannelReactionRule {
        channelSettings.reactionRule(id)
    }

    func setReactionRule(_ rule: ChannelReactionRule, for id: String) {
        channelSettings.update(id, log: .reactionsChanged) { settings in
            settings.reactionRule = rule
        }
    }

    func rename(_ id: String, to name: String) {
        mutate(id) { chat in
            chat.name = name
        }
    }

    func setPublic(_ isPublic: Bool, id: String) {
        mutate(id) { chat in
            chat.isPublic = isPublic
        }
    }

    func unsubscribe(_ id: String) {
        guard var chat = chat(id), isJoined(id) else {
            return
        }

        chat.memberCount = max(0, chat.memberCount - 1)
        previews[id] = chat
        delete(id)
    }

    func isPostReported(_ id: String) -> Bool {
        reportedPosts.contains(id)
    }

    func reportPost(_ id: String) {
        reportedPosts.insert(id)
    }

    func reportChannel(_ id: String) {
        reportedChannels.insert(id)
    }

    func isJoined(_ id: String) -> Bool {
        chats.contains { chat in
            chat.id == id
        }
    }

    func subscribe(_ id: String) {
        guard var chat = previews.removeValue(forKey: id) else {
            return
        }

        chat.date = Date()
        chat.memberCount += 1
        chats.insert(chat, at: 0)
        observers.notify(chats)
    }

    func toggleRead(_ id: String) {
        mutate(id) { chat in
            chat.unread = chat.unread > 0 ? 0 : 1
        }
    }

    func togglePin(_ id: String) {
        mutate(id) { chat in
            chat.isPinned.toggle()
        }
    }

    func toggleMute(_ id: String) {
        mutate(id) { chat in
            chat.isMuted.toggle()
        }
    }

    func toggleArchive(_ id: String) {
        mutate(id) { chat in
            chat.isArchived.toggle()
        }
    }

    func recordOutgoing(_ text: String, date: Date, in id: String) {
        mutate(id) { chat in
            chat.message = ChatSummary.outgoingPrefix + text
            chat.date = date
            chat.unread = 0
            chat.outgoingRead = false
        }
    }

    func recordIncoming(_ message: HistoryMessage, in id: String, countsUnread: Bool) {
        mutate(id) { chat in
            let text = ChatsStore.preview(of: message)
            chat.message = chat.kind == .group ? "\(message.authorName): \(text)" : text
            chat.date = message.date
            chat.outgoingRead = nil
            if countsUnread {
                chat.unread += 1
            }
        }
    }

    static func preview(of message: HistoryMessage) -> String {
        guard message.entities.contains(where: \.isSpoiler), case .text(let text) = message.content else {
            return preview(of: message.content)
        }

        return MessageEntity.masked(text, entities: message.entities)
    }

    static func preview(of content: MessageContent) -> String {
        switch content {
        case .service:
            "📌"
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

    func recordEdit(_ message: HistoryMessage, in id: String) {
        mutate(id) { chat in
            guard chat.date == message.date else {
                return
            }

            let text = ChatsStore.preview(of: message)
            if message.isOutgoing {
                chat.message = ChatSummary.outgoingPrefix + text
            } else {
                chat.message = chat.kind == .group ? "\(message.authorName): \(text)" : text
            }
        }
    }

    func markOutgoingRead(_ id: String, date: Date) {
        mutate(id) { chat in
            if chat.date == date {
                chat.outgoingRead = true
            }
        }
    }

    func setDraft(_ text: String, for id: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = trimmed.isEmpty ? nil : text
        guard chat(id)?.draft != draft else {
            return
        }

        mutate(id) { chat in
            chat.draft = draft
            chat.draftDate = draft == nil ? nil : Date()
        }
    }

    func delete(_ id: String) {
        chats.removeAll { chat in
            chat.id == id
        }
        observers.notify(chats)
    }

    func observe(_ onChange: @escaping @MainActor @Sendable ([ChatSummary]) -> Void) -> ObservationToken {
        let token = observers.add(onChange)
        onChange(chats)

        return token
    }

    func setTyping(_ name: String?, in id: String) {
        guard chat(id)?.typing != name else {
            return
        }

        mutate(id) { chat in
            chat.typing = name
        }
    }

    private func mutate(_ id: String, _ change: (inout ChatSummary) -> Void) {
        guard let index = chats.firstIndex(where: { chat in
            chat.id == id
        }) else {
            return
        }

        change(&chats[index])
        observers.notify(chats)
    }
}
