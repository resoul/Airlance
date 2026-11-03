import AirlanceUI
import ChatHistory
import UIKit

extension ChatViewController {
    func bindFailed() {
        history.onFailedMessage = { [weak self] message, node in
            self?.showFailedMenu(message, node: node)
        }
        history.onEffect = { [weak self] effect, node in
            guard let self, let frame = node.bubbleFrame else {
                return
            }

            MessageEffectPlayer.play(effect, from: node.view.convert(frame, to: self.view), in: self.view)
        }
    }

    func retryItems(for message: HistoryMessage) -> [MenuItem] {
        guard message.isOutgoing, message.delivery == .failed else {
            return []
        }

        let item = MenuItem(
            title: presentation.strings.chatRetry,
            symbol: "arrow.clockwise",
            isDestructive: false,
            action: .run { [weak self] in
                self?.retry(message)
            }
        )

        return [item]
    }

    private func showFailedMenu(_ message: HistoryMessage, node: MessageBubbleNode) {
        guard let host = view.window, let frame = node.bubbleFrame else {
            return
        }

        inputBar.dismissKeyboard()
        let strings = presentation.strings
        let items = [
            PopupMenuItem(title: strings.chatRetry, symbol: "arrow.clockwise") { [weak self] in
                self?.retry(message)
            },
            PopupMenuItem(title: strings.chatDelete, symbol: "trash", isDestructive: true) { [weak self, weak node] in
                self?.delete(message, node: node, effect: .dissolve)
            },
        ]
        _ = PopupMenu.show(
            items,
            theme: presentation.theme,
            from: node.view.convert(frame, to: host),
            in: host,
            header: strings.chatSendFailed
        )
    }

    private func retry(_ message: HistoryMessage) {
        history.scrollsToBottom = true
        dependencies.historyStore.retry(message.id, in: id)
    }
}
