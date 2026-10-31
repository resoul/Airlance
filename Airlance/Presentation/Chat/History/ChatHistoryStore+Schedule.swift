import ChatHistory
import Foundation

struct SendOptions: Sendable {
    var entities: [MessageEntity] = []
    var isSilent = false
}

struct ScheduledMessage: Sendable, Identifiable {
    let id: String
    let text: String
    let date: Date
    let replyTo: HistoryMessage?
    let quote: MessageQuote?
    let options: SendOptions
}

extension ChatHistoryStore {
    func scheduledMessages(in id: String) -> [ScheduledMessage] {
        scheduled[id] ?? []
    }

    func schedule(_ message: ScheduledMessage, in id: String) {
        scheduled[id, default: []].append(message)
        scheduled[id]?.sort { lhs, rhs in
            lhs.date < rhs.date
        }
        let delay = max(0, message.date.timeIntervalSinceNow)
        scheduleTasks[message.id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }

            self?.sendScheduled(message.id, in: id)
        }
        changed(id)
    }

    func sendScheduled(_ messageID: String, in id: String) {
        guard let message = removeScheduled(messageID, in: id) else {
            return
        }

        send(message.text, to: id, replyTo: message.replyTo, quote: message.quote, options: message.options)
    }

    func cancelScheduled(_ messageID: String, in id: String) {
        if removeScheduled(messageID, in: id) != nil {
            changed(id)
        }
    }

    private func removeScheduled(_ messageID: String, in id: String) -> ScheduledMessage? {
        scheduleTasks[messageID]?.cancel()
        scheduleTasks[messageID] = nil
        guard let index = scheduled[id]?.firstIndex(where: { message in
            message.id == messageID
        }) else {
            return nil
        }

        return scheduled[id]?.remove(at: index)
    }
}
