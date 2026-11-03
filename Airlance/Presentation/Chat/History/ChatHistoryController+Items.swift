import ChatHistory
import ListUI
import Observers
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

    func edit(_ messageID: String, composed: ComposedText) {
        store.edit(messageID, text: composed.text, entities: composed.entities, in: chatID)
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
        scrollAndFlash(id, quote: pendingQuote)
        pendingQuote = nil
    }

    private func message(_ id: String, layout: MessageBubbleLayout, style: HistoryStyle) -> MessageBubbleItem {
        let isBare = layout.videoNote != nil || layout.isBare
        let color = isBare ? .clear : style.bubble(outgoing: layout.isOutgoing)
        let transfer = transferProgress(id)
        guard !isReadOnly else {
            return MessageBubbleItem(layout: layout, color: color, messageID: id, transfer: transfer)
        }

        return MessageBubbleItem(
            layout: layout,
            color: color,
            messageID: id,
            onLongPress: { [weak self] node in
                self?.longPressed(id, node: node)
            },
            onLinkLongPress: { [weak self] node, url, point in
                self?.onLinkMenu?(url, node, point)
            },
            onPhotoTap: { [weak self] node, index in
                self?.photoTapped(id, index: index, node: node)
            },
            onAction: { [weak self] action in
                self?.perform(action, messageID: id)
            },
            onBubbleTap: { [weak self] in
                self?.bubbleTapped(id)
            },
            selection: selection.map { selection in
                selection.contains(id) ? .selected : .unselected
            },
            selectionTint: style.tint(outgoing: false),
            search: searchHighlight(for: id),
            onToggleSelection: { [weak self] in
                self?.toggleSelection(id)
            },
            spoilersRevealed: revealedSpoilers.contains(id),
            spoilerInk: style.text(outgoing: layout.isOutgoing),
            onRevealSpoiler: { [weak self] in
                self?.revealedSpoilers.insert(id)
            },
            transfer: transfer
        )
    }

    private func transferProgress(_ id: String) -> @MainActor () -> TransferProgress? {
        let transfers = store.transfers
        let key = TransferKey(chatID: chatID, messageID: id)

        return {
            transfers.progress(key)
        }
    }

    private func perform(_ action: BubbleAction.Kind, messageID: String) {
        switch action {
        case .url(let url):
            onOpenURL?(url)
        case .reply(let id, let quote):
            reveal(id, quote: quote)
        case .voice:
            toggleVoice(messageID)
        case .file:
            toggleFile(messageID)
        case .comments:
            onOpenComments?(messageID)
        case .reaction(let emoji):
            react(emoji, messageID: messageID)
        case .pollOption(let index):
            pollOptionTapped(index, messageID: messageID)
        case .pollVote:
            submitPollDraft(messageID)
        case .pollResults:
            onPollResults?(messageID)
        case .pollExplanation:
            showExplanation(messageID)
        case .videoNote:
            (listView.node(for: messageID) as? MessageBubbleNode)?.toggleVideoNote()
        case .videoReaction(let reactionID):
            onVideoReaction?(messageID, reactionID)
        case .expand:
            expandText(messageID)
        case .effect:
            playEffect(messageID)
        case .transcribe:
            onTranscribe?(messageID)
        case .forwardSource(let chatID):
            onOpenChat?(chatID)
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

        toggleTransfer(messageID)
    }

    func toggleTransfer(_ messageID: String) {
        if store.transfers.progress(TransferKey(chatID: chatID, messageID: messageID)) != nil {
            store.cancelTransfer(messageID, in: chatID)
        } else {
            store.download(messageID, in: chatID)
        }
    }

    func bindTransfers() -> ObservationToken {
        store.transfers.observe { [weak self] event in
            guard let self, event.key.chatID == self.chatID else {
                return
            }

            (self.listView.node(for: event.key.messageID) as? MessageBubbleNode)?.applyTransfer(event.progress)
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
            let url = voice.source.url
        else {
            return
        }

        voicePlayback.toggle(messageID, url: url)
        if !message.isListened {
            markListened(messageID)
        }
    }

    func scrollAndFlash(_ id: String, quote: MessageQuote? = nil) {
        listView.scrollToItem(id, animated: true)
        let tint = style?.name ?? .systemBlue
        let text = message(id)?.content.text ?? ""
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let node = self?.listView.node(for: id) as? MessageBubbleNode else {
                return
            }

            if let range = quote?.range(in: text), node.flashText(range, color: tint.withAlphaComponent(0.3)) {
                return
            }

            node.flash(color: tint.withAlphaComponent(0.16))
        }
    }
}
