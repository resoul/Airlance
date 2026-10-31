import UIKit

extension ChatHistoryController {
    var translations: [String: MessageTranslation] {
        get {
            store.translations[chatID] ?? [:]
        }
        set {
            store.translations[chatID] = newValue
        }
    }

    var revealedSpoilers: Set<String> {
        get {
            store.revealedSpoilers[chatID] ?? []
        }
        set {
            store.revealedSpoilers[chatID] = newValue
        }
    }

    func setTranslation(_ translation: MessageTranslation?, messageID: String) {
        let node = listView.node(for: messageID) as? MessageBubbleNode
        let dissolved = node?.dissolveText() ?? false
        translations[messageID] = translation
        pendingTextReveal = messageID
        guard dissolved else {
            reload(animated: true)

            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.reload(animated: true)
        }
    }

    func revealTranslatedText() {
        guard let id = pendingTextReveal, let node = listView.node(for: id) as? MessageBubbleNode else {
            return
        }

        pendingTextReveal = nil
        node.revealText()
    }
}
