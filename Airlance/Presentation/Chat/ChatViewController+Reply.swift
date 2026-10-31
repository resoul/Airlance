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
        inputBar.onSend = { [weak self] composed in
            self?.send(composed)
        }
    }

    func startReply(_ messageID: String, quote: MessageQuote? = nil) {
        guard let message = history.message(messageID) else {
            return
        }

        if editTarget != nil {
            endEdit()
        }
        replyTarget = message
        replyQuote = quote
        inputBar.showPanel(ChatPanelContent(
            symbol: quote == nil ? "arrowshape.turn.up.left" : "text.quote",
            title: authorName(of: message),
            text: quote?.text ?? snippet(of: message),
            closeLabel: presentation.strings.chatReplyCancel
        ))
        inputBar.focus()
        let color = presentation.theme.colors.accent.withAlphaComponent(0.16)
        (history.listView.node(for: messageID) as? MessageBubbleNode)?.flash(color: color)
    }

    func showForward(_ messages: [HistoryMessage]) {
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

            for message in messages {
                self.history.forward(message, authorName: self.authorName(of: message), to: chat.id)
            }
            Toast(strings.chatForwardedTo(chat.name), symbol: "arrowshape.turn.up.right.fill")
                .show(theme: self.presentation.theme, in: self.view)
        }
        picker.show()
    }

    func sendVoice(_ voice: MessageVoice) {
        history.sendVoice(voice, replyTo: replyTarget, quote: replyQuote)
        cancelReply()
    }

    func send(_ composed: ComposedText, isSilent: Bool = false) {
        guard editTarget == nil else {
            finishEdit(composed)

            return
        }

        let options = SendOptions(entities: composed.entities, isSilent: isSilent)
        history.send(composed.text, replyTo: replyTarget, quote: replyQuote, options: options)
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
        replyQuote = nil
        inputBar.hidePanel()
    }

    func authorName(of message: HistoryMessage) -> String {
        if message.isOutgoing {
            return presentation.strings.chatYou
        }

        return message.authorName.isEmpty ? dependencies.chatsStore.chat(id)?.name ?? "" : message.authorName
    }

    func snippet(of message: HistoryMessage) -> String {
        if case .text(let text) = message.content, message.entities.contains(where: \.isSpoiler) {
            return MessageEntity.masked(text, entities: message.entities)
        }

        return MessageSnippet.text(message.content, strings: presentation.strings)
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
        case .poll(let poll):
            return "📊 " + poll.question
        case .videoNote:
            return strings.videoNotesPreview
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
