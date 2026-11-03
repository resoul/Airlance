import ChatHistory
import Foundation
import Observers

extension ChatHistoryStore {
    private static let vanishDelay: UInt64 = 900_000_000

    func observeExpirations(_ onExpire: @escaping @MainActor @Sendable (IncomingMessage) -> Void) -> ObservationToken {
        expirations.add(onExpire)
    }

    func scheduleExpiry(_ message: HistoryMessage, in id: String) {
        guard let expiresAt = message.expiresAt else {
            return
        }

        Task { [weak self] in
            let delay = expiresAt.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            self?.expire(message.id, in: id)
        }
    }

    private func expire(_ messageID: String, in id: String) {
        guard !isShutDown, let message = message(messageID, in: id) else {
            return
        }

        expirations.notify(IncomingMessage(chatID: id, message: message))
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.vanishDelay)
            self?.delete(messageID, from: id)
        }
    }
}
