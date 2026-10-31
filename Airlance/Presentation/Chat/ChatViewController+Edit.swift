import ChatHistory
import Haptics
import UIKit

extension ChatViewController {
    func editItem(for message: HistoryMessage) -> MenuItem {
        MenuItem(
            title: presentation.strings.chatEdit,
            symbol: "pencil",
            isDestructive: false,
            action: .run { [weak self] in
                self?.startEdit(message)
            }
        )
    }

    func startEdit(_ message: HistoryMessage) {
        let strings = presentation.strings
        if editTarget == nil {
            draftBeforeEdit = inputBar.text
        }
        replyTarget = nil
        editTarget = message
        inputBar.isEditingMessage = true
        inputBar.showPanel(ChatPanelContent(
            symbol: "pencil",
            title: strings.chatEditing,
            text: snippet(of: message),
            closeLabel: strings.chatEditCancel
        ))
        inputBar.setComposed(ComposedText(text: message.content.text, entities: message.entities), animated: true)
        inputBar.focus()
        let color = presentation.theme.colors.accent.withAlphaComponent(0.16)
        (history.listView.node(for: message.id) as? MessageBubbleNode)?.flash(color: color)
    }

    func finishEdit(_ composed: ComposedText) {
        guard let editTarget else {
            return
        }

        if case .text = editTarget.content, composed.text.isEmpty {
            Haptics.play(.warning)

            return
        }

        history.edit(editTarget.id, composed: composed)
        Haptics.play(.success)
        endEdit()
    }

    func endEdit() {
        editTarget = nil
        inputBar.isEditingMessage = false
        inputBar.hidePanel()
        inputBar.setText(draftBeforeEdit ?? "", animated: true)
        draftBeforeEdit = nil
    }
}
