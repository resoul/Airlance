import ChatHistory
import ToastUI
import UIKit

extension ChatViewController {
    func bindReply() {
        history.replySwipe.onReply = { [weak self] id in
            self?.startReply(id)
        }
        inputBar.replyPanel.onClose = { [weak self] in
            self?.closePanel()
        }
        inputBar.onSend = { [weak self] text in
            self?.send(text)
        }
    }

    func startReply(_ messageID: String) {
        guard let message = history.message(messageID) else {
            return
        }

        if editTarget != nil {
            endEdit()
        }
        replyTarget = message
        inputBar.showPanel(ChatPanelContent(
            symbol: "arrowshape.turn.up.left",
            title: authorName(of: message),
            text: snippet(of: message),
            closeLabel: presentation.strings.chatReplyCancel
        ))
        inputBar.focus()
        let color = presentation.theme.colors.accent.withAlphaComponent(0.16)
        (history.listView.node(for: messageID) as? MessageBubbleNode)?.flash(color: color)
    }

    func showForward(_ message: HistoryMessage) {
        inputBar.dismissKeyboard()
        let chats = dependencies.chatsStore.chats
            .filter { chat in
                !chat.isArchived && chat.kind != .channel
            }
            .sorted { lhs, rhs in
                lhs.isPinned != rhs.isPinned ? lhs.isPinned : lhs.activityDate > rhs.activityDate
            }
        let strings = presentation.strings
        let picker = ForwardPickerView(chats: chats, title: strings.chatForward, presentation: presentation, host: view)
        picker.onSelect = { [weak self] chat in
            guard let self else {
                return
            }

            self.history.forward(message, authorName: self.authorName(of: message), to: chat.id)
            Toast(strings.chatForwardedTo(chat.name), symbol: "arrowshape.turn.up.right.fill")
                .show(theme: self.presentation.theme, in: self.view)
        }
        picker.show()
    }

    func sendVoice(_ voice: MessageVoice) {
        history.sendVoice(voice, replyTo: replyTarget)
        cancelReply()
    }

    private func send(_ text: String) {
        guard editTarget == nil else {
            finishEdit(text)

            return
        }

        history.send(text, replyTo: replyTarget)
        cancelReply()
        inputBar.clear()
    }

    private func closePanel() {
        if editTarget != nil {
            endEdit()
        } else {
            cancelReply()
        }
    }

    func cancelReply() {
        replyTarget = nil
        inputBar.hidePanel()
    }

    private func authorName(of message: HistoryMessage) -> String {
        if message.isOutgoing {
            return presentation.strings.chatYou
        }

        return message.authorName.isEmpty ? dependencies.chatsStore.chat(id)?.name ?? "" : message.authorName
    }

    func snippet(of message: HistoryMessage) -> String {
        MessageSnippet.text(message.content, strings: presentation.strings)
    }
}

enum MessageSnippet {
    static func text(_ content: MessageContent, strings: AppStrings) -> String {
        switch content {
        case .voice:
            return strings.chatVoiceMessage
        case .location(let location):
            return location.title ?? strings.chatLocation
        case .file(let file, let caption):
            return caption.isEmpty ? file.name : caption
        case .text, .photos, .service:
            break
        }

        let text = content.text
        guard text.isEmpty, case .photos(let photos, _) = content else {
            return text
        }

        return photos.first?.video == nil ? strings.chatPhoto : strings.chatVideo
    }
}
