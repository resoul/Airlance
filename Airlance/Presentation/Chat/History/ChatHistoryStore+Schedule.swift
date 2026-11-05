import ChatHistory
import Foundation
import Protocol

struct SendOptions: Sendable {
    var entities: [MessageEntity] = []
    var isSilent = false
    var effect: String?
    var lifetime: TimeInterval?
}

enum ScheduleRepeat: String, CaseIterable, Sendable {
    case never
    case daily
    case weekly
    case biweekly
    case monthly

    func next(after date: Date, calendar: Calendar = .current) -> Date? {
        var next = date
        repeat {
            let step: Date?
            switch self {
            case .never:
                return nil
            case .daily:
                step = calendar.date(byAdding: .day, value: 1, to: next)
            case .weekly:
                step = calendar.date(byAdding: .day, value: 7, to: next)
            case .biweekly:
                step = calendar.date(byAdding: .day, value: 14, to: next)
            case .monthly:
                step = calendar.date(byAdding: .month, value: 1, to: next)
            }
            guard let step else {
                return nil
            }

            next = step
        } while next <= Date()

        return next
    }
}

struct ScheduledMessage: Sendable, Identifiable {
    let id: String
    let text: String
    var date: Date
    let replyTo: HistoryMessage?
    let quote: MessageQuote?
    let options: SendOptions
    var repeatRule = ScheduleRepeat.never
    var serverID: String?
    var isFailed = false
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
        if let serverScheduled, chatsStore.chat(id)?.isServer == true {
            serverScheduled.add(message, chatID: id)
            changed(id)

            return
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

        if let serverID = message.serverID {
            serverScheduled?.sendNow(serverID)

            return
        }

        send(message.text, to: id, replyTo: message.replyTo, quote: message.quote, options: message.options)
        if let next = message.repeatRule.next(after: message.date) {
            var repeated = message
            repeated.date = next
            schedule(repeated, in: id)
        }
    }

    func cancelScheduled(_ messageID: String, in id: String) {
        guard let message = removeScheduled(messageID, in: id) else {
            return
        }

        if let serverID = message.serverID {
            serverScheduled?.cancel(serverID)
        }
        changed(id)
    }

    func setServerScheduled(_ items: [ServerScheduled]) {
        let affected = Set(scheduled.keys).union(items.map(\.chatID))
        let rules = ScheduleRepeat.allCases
        var next: [String: [ScheduledMessage]] = [:]
        for item in items {
            let rule = rules.indices.contains(Int(item.repeatRule)) ? rules[Int(item.repeatRule)] : .never
            next[item.chatID, default: []].append(ScheduledMessage(
                id: item.clientID,
                text: item.text,
                date: Date(timeIntervalSince1970: TimeInterval(item.sendAtUnixMs) / 1000),
                replyTo: nil,
                quote: nil,
                options: SendOptions(),
                repeatRule: rule,
                serverID: item.id,
                isFailed: !item.failure.isEmpty
            ))
        }
        scheduled = next
        for id in affected {
            changed(id)
        }
    }

    func markScheduledFailed(_ messageID: String, in id: String) {
        guard let index = scheduled[id]?.firstIndex(where: { message in
            message.id == messageID
        }) else {
            return
        }

        scheduled[id]?[index].isFailed = true
        changed(id)
    }

    func scheduledPreviews(in id: String) -> [HistoryMessage] {
        scheduledMessages(in: id).map { message in
            var preview = HistoryMessage(
                id: message.id,
                authorID: "me",
                authorName: "",
                isOutgoing: true,
                date: message.date,
                content: .text(message.text),
                delivery: message.isFailed ? .failed : .sending,
                reply: message.replyTo.map { reply in
                    MessageReply(reply, quote: message.quote)
                },
                link: nil
            )
            preview.entities = MessageEntity.valid(message.options.entities, in: message.text)

            return preview
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
