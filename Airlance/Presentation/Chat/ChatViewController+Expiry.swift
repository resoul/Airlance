import AirlanceUI
import ChatHistory
import EffectsUI
import Observers
import UIKit

extension ChatViewController {
    static let lifetimes: [TimeInterval] = [10, 60, 3_600, 86_400]

    func bindExpirations() -> ObservationToken {
        dependencies.historyStore.observeExpirations { [weak self] expired in
            guard let self, expired.chatID == self.history.chatID else {
                return
            }

            self.vanish(expired.message.id)
        }
    }

    func showLifetimeMenu() {
        guard let host = view.window else {
            return
        }

        let strings = presentation.strings
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        var calendar = Calendar.current
        calendar.locale = strings.pack.locale
        formatter.calendar = calendar
        let anchor = inputBar.convert(inputBar.actionIcon.frame, to: host)
        let items = Self.lifetimes.map { lifetime in
            PopupMenuItem(title: formatter.string(from: lifetime) ?? "", symbol: "timer") { [weak self] in
                guard let self else {
                    return
                }

                self.send(ComposedText(attributed: self.inputBar.textView.attributedText), lifetime: lifetime)
            }
        }
        PopupMenu.show(items, theme: presentation.theme, from: anchor, in: host, header: strings.chatSendTimer)
    }

    private func vanish(_ messageID: String) {
        guard
            let node = history.listView.node(for: messageID) as? MessageBubbleNode,
            let frame = node.bubbleFrame,
            ViewEffects.play(.dissolve, on: node.view, rect: frame)
        else {
            return
        }

        node.view.alpha = 0
    }
}
