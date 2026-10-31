import ChatHistory
import Foundation

extension ChatHistoryStore {
    func updatePoll(_ messageID: String, in id: String, change: (inout MessagePoll) -> Void) {
        update(messageID, in: id) { message in
            guard case .poll(var poll) = message.content else {
                return
            }

            change(&poll)
            message.content = .poll(poll)
        }
    }

    func sendPoll(_ poll: MessagePoll, to id: String, silent: Bool = false) {
        let message = postContent(.poll(poll), to: id, isSilent: silent)
        if let date = poll.closeDate {
            schedulePollClose(message.id, in: id, at: date)
        }
    }
}

extension ChatHistoryStore {
    func watchPollDeadlines(in id: String) {
        for message in history(for: id)?.messages ?? [] {
            guard case .poll(let poll) = message.content, !poll.isClosed, let date = poll.closeDate else {
                continue
            }

            schedulePollClose(message.id, in: id, at: date)
        }
    }

    func schedulePollClose(_ messageID: String, in id: String, at date: Date) {
        let key = "poll:\(messageID)"
        guard scheduleTasks[key] == nil else {
            return
        }

        let delay = max(0, date.timeIntervalSinceNow)
        scheduleTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else {
                return
            }

            self.scheduleTasks[key] = nil
            self.updatePoll(messageID, in: id) { poll in
                poll.isClosed = true
            }
        }
    }
}
