import AirlanceUI
import ChatHistory
import ToastUI
import UIKit

extension ChatViewController {
    func pollItems(for message: HistoryMessage) -> [MenuItem] {
        guard case .poll(let poll) = message.content, !poll.isClosed else {
            return []
        }

        let strings = presentation.strings
        var items: [MenuItem] = []
        if poll.canRetract {
            items.append(MenuItem(
                title: strings.pollRetract,
                symbol: "arrow.uturn.backward",
                isDestructive: false,
                action: .run { [weak self] in
                    self?.history.retractVote(message.id)
                }
            ))
        }
        if message.isOutgoing {
            items.append(MenuItem(
                title: strings.pollStop,
                symbol: "stop.circle",
                isDestructive: true,
                action: .run { [weak self] in
                    self?.history.stopPoll(message.id)
                }
            ))
        }

        return items
    }

    func bindPolls() {
        history.onPollResults = { [weak self] messageID in
            self?.showPollResults(messageID)
        }
        history.onPollFeedback = { [weak self] text, isCorrect in
            self?.showPollFeedback(text, isCorrect: isCorrect)
        }
    }

    private func showPollFeedback(_ text: String, isCorrect: Bool?) {
        let strings = presentation.strings
        let symbol: String
        var message = text
        switch isCorrect {
        case true?:
            symbol = "checkmark.seal.fill"
            message = strings.pollCorrect + " " + text
        case false?:
            symbol = "xmark.seal.fill"
            message = strings.pollWrong + ". " + text
        case nil:
            symbol = "lightbulb.fill"
        }
        Toast(message, symbol: symbol).show(theme: presentation.theme, in: view)
    }

    private func showPollResults(_ messageID: String) {
        guard let poll = history.poll(messageID) else {
            return
        }

        inputBar.dismissKeyboard()
        let results = PollResultsController(poll: poll, presentation: presentation)
        present(UINavigationController(rootViewController: results), animated: true)
    }

    var canCreatePolls: Bool {
        let kind = thread == nil ? dependencies.chatsStore.chat(id)?.kind : nil

        return canWrite && (kind == .group || kind == .channel)
    }

    func composePoll() {
        inputBar.dismissKeyboard()
        let composer = PollComposerController(presentation: presentation)
        composer.onCreate = { [weak self] poll in
            guard let self else {
                return
            }

            self.history.scrollsToBottom = true
            self.dependencies.historyStore.sendPoll(poll, to: self.id)
        }
        present(UINavigationController(rootViewController: composer), animated: true)
    }
}
