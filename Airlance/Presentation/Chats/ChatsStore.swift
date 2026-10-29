import ChatHistory
import Foundation
import Observers

@MainActor
final class ChatsStore {
    private(set) var chats: [ChatSummary]

    private let observers = ObserverList<[ChatSummary]>()

    init(chats: [ChatSummary]) {
        self.chats = chats
    }

    func chat(_ id: String) -> ChatSummary? {
        chats.first { chat in
            chat.id == id
        }
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
            let text = ChatsStore.preview(of: message.content)
            chat.message = chat.kind == .group ? "\(message.authorName): \(text)" : text
            chat.date = message.date
            chat.outgoingRead = nil
            if countsUnread {
                chat.unread += 1
            }
        }
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

            let text = ChatsStore.preview(of: message.content)
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
