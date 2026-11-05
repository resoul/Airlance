import ChatHistory
import Foundation
import Network

@MainActor
final class DemoNetwork {
    static let shared = DemoNetwork()

    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in
                DemoNetwork.shared.isOnline = isOnline
            }
        }
        monitor.start(queue: DispatchQueue(label: "airlance.demo-network"))
    }
}

extension ChatHistoryStore {
    private static let failDelay: UInt64 = 1_500_000_000

    func failIfOffline(_ message: HistoryMessage, in id: String) -> Bool {
        guard !DemoNetwork.shared.isOnline else {
            return false
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.failDelay)
            self?.update(message.id, in: id) { message in
                message.delivery = .failed
            }
        }

        return true
    }

    func retry(_ messageID: String, in id: String) {
        guard var message = histories[id]?.messages.first(where: { message in
            message.id == messageID
        }), message.delivery == .failed else {
            return
        }

        delete(messageID, from: id)
        message.delivery = .sending
        message.date = Date()
        append(message, to: id)
        chatsStore.recordOutgoing(
            ChatsStore.preview(of: message),
            date: message.date,
            in: id,
            preview: ChatRowPreview(message)
        )
        deliver(message, in: id)
    }
}
