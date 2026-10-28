import Observers

@MainActor
final class ChatsStore {
    private(set) var chats: [ChatSummary]

    private let observers = ObserverList<[ChatSummary]>()

    init(chats: [ChatSummary]) {
        self.chats = chats
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
