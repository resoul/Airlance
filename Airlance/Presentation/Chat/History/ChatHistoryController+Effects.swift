import UIKit

extension ChatHistoryController {
    func playEffect(_ messageID: String) {
        guard
            let effect = message(messageID)?.effect,
            let node = listView.node(for: messageID) as? MessageBubbleNode
        else {
            return
        }

        onEffect?(effect, node)
    }

    func playPendingEffects() {
        for id in pendingEffects {
            guard message(id) != nil else {
                pendingEffects.remove(id)
                continue
            }

            guard listView.node(for: id) is MessageBubbleNode else {
                continue
            }

            pendingEffects.remove(id)
            playEffect(id)
        }
    }
}
