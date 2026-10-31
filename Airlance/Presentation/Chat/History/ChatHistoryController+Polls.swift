import ChatHistory
import Haptics
import UIKit

extension ChatHistoryController {
    func poll(_ messageID: String) -> MessagePoll? {
        guard case .poll(let poll) = message(messageID)?.content else {
            return nil
        }

        return poll
    }

    func pollOptionTapped(_ index: Int, messageID: String) {
        guard let poll = poll(messageID), !poll.showsResults else {
            return
        }

        guard poll.allowsMultiple else {
            vote([index], messageID: messageID)

            return
        }

        var draft = pollDrafts[messageID] ?? []
        if draft.contains(index) {
            draft.remove(index)
        } else {
            draft.insert(index)
        }
        pollDrafts[messageID] = draft
        Haptics.play(.selection)
        reload(animated: false)
    }

    func submitPollDraft(_ messageID: String) {
        if let draft = pollDrafts[messageID], !draft.isEmpty {
            vote(draft, messageID: messageID)
        }
    }

    func retractVote(_ messageID: String) {
        store.updatePoll(messageID, in: chatID) { poll in
            poll.retract(by: Reactions.me)
        }
    }

    func showExplanation(_ messageID: String) {
        if let explanation = poll(messageID)?.explanation, !explanation.isEmpty {
            Haptics.play(.tap)
            onPollFeedback?(explanation, nil)
        }
    }

    func stopPoll(_ messageID: String) {
        store.updatePoll(messageID, in: chatID) { poll in
            poll.isClosed = true
        }
    }

    private func vote(_ indices: Set<Int>, messageID: String) {
        guard var result = poll(messageID) else {
            return
        }

        pollDrafts[messageID] = nil
        result.vote(indices, by: Reactions.me)
        store.updatePoll(messageID, in: chatID) { poll in
            poll.vote(indices, by: Reactions.me)
        }
        guard let isCorrect = result.answeredCorrectly else {
            Haptics.play(.success)

            return
        }

        Haptics.play(isCorrect ? .success : .warning)
        if !isCorrect {
            (listView.node(for: messageID) as? MessageBubbleNode)?.shake()
        }
        if let explanation = result.explanation, !explanation.isEmpty {
            onPollFeedback?(explanation, isCorrect)
        }
    }
}
