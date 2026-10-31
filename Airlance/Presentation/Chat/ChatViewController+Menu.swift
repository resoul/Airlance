import ChatHistory
import EffectsUI
import ToastUI
import UIKit

extension ChatViewController {
    func showMenu(for message: HistoryMessage, node: MessageBubbleNode) {
        guard let frame = node.bubbleFrame, let host = view.window else {
            return
        }

        inputBar.dismissKeyboard()
        let menu = MessageMenuView(
            bubble: node.view,
            frame: frame,
            outgoing: node.isOutgoing,
            items: menuItems(for: message, node: node),
            presentation: presentation,
            visible: view.convert(visibleHistoryFrame, to: host),
            extras: MessageMenuExtras(
                selection: textSelection(for: message, node: node),
                reactions: MessageMenuReactions(chosen: message.chosenReaction) { [weak self] emoji in
                    self?.history.react(emoji, messageID: message.id)
                },
                receipts: menuReceipts(for: message)
            ),
            host: host
        )
        activeMenu = menu
        menu.show()
    }

    private func textSelection(for message: HistoryMessage, node: MessageBubbleNode) -> MessageMenuSelection? {
        node.selectableText(message.content.text).map { text in
            MessageMenuSelection(text: text) { [weak self] selected, range in
                self?.selectionItems(selected, range: range, message: message) ?? []
            }
        }
    }

    private func selectionItems(_ text: String, range: NSRange, message: HistoryMessage) -> [MenuItem] {
        let quote = MenuItem(
            title: presentation.strings.chatReplyQuote,
            symbol: "text.quote",
            isDestructive: false,
            action: .run { [weak self] in
                self?.startReply(message.id, quote: MessageQuote(text: text, offset: range.location))
            }
        )

        return canWrite ? [quote, copyItem(text)] : [copyItem(text)]
    }

    var visibleHistoryFrame: CGRect {
        let top = view.safeAreaInsets.top + pinnedHeight

        return CGRect(x: 0, y: top, width: view.bounds.width, height: max(0, bottomBarTop - top))
    }

    func trackMenu(_ gesture: UILongPressGestureRecognizer) {
        guard !trackLinkMenu(gesture), let menu = activeMenu else {
            return
        }

        switch gesture.state {
        case .changed:
            menu.track(gesture.location(in: menu), ended: false)
        case .ended:
            menu.track(gesture.location(in: menu), ended: true)
        default:
            menu.track(CGPoint(x: -1, y: -1), ended: true)
        }
    }

    private func menuItems(for message: HistoryMessage, node: MessageBubbleNode) -> [MenuItem] {
        let strings = presentation.strings
        let reply = MenuItem(
            title: strings.chatReply,
            symbol: "arrowshape.turn.up.left",
            isDestructive: false,
            action: .run { [weak self] in
                self?.startReply(message.id)
            }
        )
        var items = canWrite ? [reply] : []
        let text = message.content.text
        if !text.isEmpty {
            items.append(copyItem(text))
            items.append(contentsOf: translateItems(for: message))
            items.append(contentsOf: pollItems(for: message))
        }
        if message.isOutgoing, message.content.isEditable {
            items.append(editItem(for: message))
        }
        let forward = MenuItem(
            title: strings.chatForward,
            symbol: "arrowshape.turn.up.right",
            isDestructive: false,
            action: .run { [weak self] in
                self?.showForward([message])
            }
        )
        items.append(contentsOf: [forward] + videoReactionItems(for: message))
        items.append(pinItem(for: message))
        items.append(selectItem(for: message))
        let delete = MenuItem(
            title: strings.chatDelete,
            symbol: "trash",
            isDestructive: true,
            action: .submenu(deleteItems(for: message, node: node))
        )
        items.append(delete)

        return items
    }

    private func selectItem(for message: HistoryMessage) -> MenuItem {
        MenuItem(
            title: presentation.strings.chatSelect,
            symbol: "checkmark.circle",
            isDestructive: false,
            action: .run { [weak self] in
                self?.startSelecting(message.id)
            }
        )
    }

    private func copyItem(_ text: String) -> MenuItem {
        let copied = presentation.strings.chatCopied

        return MenuItem(
            title: presentation.strings.chatCopy,
            symbol: "doc.on.doc",
            isDestructive: false,
            action: .run { [weak self] in
                UIPasteboard.general.string = text
                self?.showToast(copied, symbol: "doc.on.doc.fill")
            }
        )
    }

    private func deleteItems(for message: HistoryMessage, node: MessageBubbleNode) -> [MenuItem] {
        let strings = presentation.strings
        let chat = dependencies.chatsStore.chat(id)
        var items: [MenuItem] = []
        if chat?.kind == .person {
            let title = strings.chatDeleteForBoth(chat?.name ?? "")
            items.append(deleteItem(title, effect: .burn, message: message, node: node))
        } else if message.isOutgoing {
            items.append(deleteItem(strings.chatDeleteForEveryone, effect: .burn, message: message, node: node))
        }
        items.append(deleteItem(strings.chatDeleteForMe, effect: .dissolve, message: message, node: node))

        return items
    }

    private func deleteItem(
        _ title: String,
        effect: ViewEffects.Kind,
        message: HistoryMessage,
        node: MessageBubbleNode
    ) -> MenuItem {
        MenuItem(title: title, symbol: nil, isDestructive: true, action: .run { [weak self, weak node] in
            self?.delete(message, node: node, effect: effect)
        })
    }

    func delete(_ message: HistoryMessage, node: MessageBubbleNode?, effect: ViewEffects.Kind) {
        guard let node, node.itemID == message.id, let frame = node.bubbleFrame,
              ViewEffects.play(effect, on: node.view, rect: frame) else {
            history.deleteMessage(message.id)

            return
        }

        node.view.alpha = 0
        let delay: TimeInterval = effect == .burn ? 1.5 : 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.history.deleteMessage(message.id)
        }
    }

    func showToast(_ text: String, symbol: String) {
        Toast(text, symbol: symbol).show(theme: presentation.theme, in: view)
    }
}
