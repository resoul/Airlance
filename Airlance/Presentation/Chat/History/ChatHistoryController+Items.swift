import ChatHistory
import ListUI
import UIKit

extension ChatHistoryController {
    func items(_ snapshot: HistorySnapshot, style: HistoryStyle) -> [any ListItem] {
        snapshot.rows.map { row -> any ListItem in
            switch row {
            case .message(let id, let layout):
                message(id, layout: layout, style: style)
            case .service(let id, let kind, let title):
                service(id, kind: kind, title: title, style: style)
            }
        }
    }

    func edit(_ messageID: String, text: String) {
        store.edit(messageID, text: text, in: chatID)
    }

    private func service(
        _ id: String,
        kind: HistoryServiceKind,
        title: String,
        style: HistoryStyle
    ) -> HistoryServiceItem {
        var item = HistoryServiceItem(id: id, kind: kind, title: title, style: style)
        if !isReadOnly, case .action(let target?) = kind {
            item.onTap = { [weak self] in
                self?.reveal(target)
            }
        }

        return item
    }

    func revealPending() {
        guard let id = pendingReveal, listView.contains(id) else {
            return
        }

        pendingReveal = nil
        scrollAndFlash(id)
    }

    private func message(_ id: String, layout: MessageBubbleLayout, style: HistoryStyle) -> MessageBubbleItem {
        let color = style.bubble(outgoing: layout.isOutgoing)
        guard !isReadOnly else {
            return MessageBubbleItem(layout: layout, color: color, messageID: id)
        }

        return MessageBubbleItem(
            layout: layout,
            color: color,
            messageID: id,
            onLongPress: { [weak self] node in
                self?.longPressed(id, node: node)
            },
            onPhotoTap: { [weak self] node, index in
                self?.photoTapped(id, index: index, node: node)
            },
            onAction: { [weak self] action in
                self?.perform(action, messageID: id)
            }
        )
    }

    private func perform(_ action: BubbleAction.Kind, messageID: String) {
        switch action {
        case .url(let url):
            onOpenURL?(url)
        case .reply(let id):
            reveal(id)
        case .voice:
            toggleVoice(messageID)
        case .file:
            toggleFile(messageID)
        }
    }

    private func toggleFile(_ messageID: String) {
        guard let message = message(messageID), case .file(let file, _) = message.content else {
            return
        }

        guard !file.isDownloaded else {
            onOpenFile?(file)

            return
        }

        let node = listView.node(for: messageID) as? MessageBubbleNode
        guard !fileDownloads.isActive(messageID) else {
            fileDownloads.cancel(messageID)
            node?.removeDownload()

            return
        }

        let duration = fileDownloads.duration(for: file)
        node?.startDownload(duration: duration)
        fileDownloads.start(messageID, duration: duration) { [weak self] in
            self?.markDownloaded(messageID)
        }
    }

    private func markDownloaded(_ messageID: String) {
        (listView.node(for: messageID) as? MessageBubbleNode)?.removeDownload()
        store.update(messageID, in: chatID) { message in
            guard case .file(var file, let caption) = message.content else {
                return
            }

            file.isDownloaded = true
            message.content = .file(file, caption: caption)
        }
    }

    func bindVoice() {
        voicePlayback.onChange = { [weak self] id, progress, isPlaying in
            (self?.listView.node(for: id) as? MessageBubbleNode)?.setVoice(progress: progress, isPlaying: isPlaying)
        }
    }

    private func toggleVoice(_ messageID: String) {
        guard
            let message = message(messageID),
            case .voice(let voice) = message.content,
            let url = ChatVoiceFixtures.url(for: voice.source)
        else {
            return
        }

        voicePlayback.toggle(messageID, url: url)
        if !message.isListened {
            markListened(messageID)
        }
    }

    func scrollAndFlash(_ id: String) {
        listView.scrollToItem(id, animated: true)
        let color = (style?.name ?? .systemBlue).withAlphaComponent(0.16)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            (self?.listView.node(for: id) as? MessageBubbleNode)?.flash(color: color)
        }
    }
}
