import ChatHistory
import ListUI
import UIKit

extension ChatHistoryController {
    func fetch(_ request: HistoryRequest, focus: String?, keepsEnd: Bool, animated: Bool = false) {
        requestRevision += 1
        let revision = requestRevision
        let chatID = chatID
        isRequesting = true
        let state = HistorySignpost.signposter.beginInterval("slice")
        let start = CACurrentMediaTime()
        Task { [weak self] in
            guard let slice = await self?.store.slice(request, in: chatID) else {
                return
            }

            HistorySignpost.signposter.endInterval("slice", state)
            guard let self, self.requestRevision == revision, self.chatID == chatID else {
                return
            }

            self.metrics?.record(.slice, seconds: CACurrentMediaTime() - start)
            self.isRequesting = false
            self.hasData = true
            self.window.setData(slice, focus: focus, keepsEnd: keepsEnd)
            self.reload(animated: animated)
        }
    }

    func historyChanged(_ event: HistoryEvent) {
        let wasAtEnd = window.isAtEnd
        let incoming = event.appended.filter { message in
            !message.isOutgoing
        }.count
        if incoming > 0, !(wasAtEnd && listView.isNearBottom) {
            unseen += incoming
            reportBottomState()
        }
        if scrollsToBottom, !wasAtEnd {
            fetch(window.latestRequest, focus: nil, keepsEnd: true)

            return
        }

        if let target = pendingReveal, window.index(of: target) == nil {
            fetch(window.request(around: target), focus: target, keepsEnd: false)

            return
        }

        let request = window.refreshRequest(removing: event.removed)
        fetch(request, focus: firstVisibleMessageID(), keepsEnd: wasAtEnd, animated: true)
    }

    func scrolled(_ list: ListView) {
        avatars.update(in: list)
        reportBottomState()
        onUpdate?()
        guard !isPreparing, let visible = visibleRange() else {
            return
        }

        if !isRequesting, let request = window.dataRequest(visible: visible) {
            fetch(request, focus: firstVisibleMessageID(), keepsEnd: false)

            return
        }

        if window.visibleChanged(visible) {
            reload()
        }
    }

    func scrollToBottom() {
        guard !window.isAtEnd else {
            listView.scrollToBottom(animated: true)

            return
        }

        scrollsToBottom = true
        fetch(window.latestRequest, focus: nil, keepsEnd: true)
    }

    func reveal(_ id: String, quote: MessageQuote? = nil) {
        guard !listView.contains(id) else {
            scrollAndFlash(id, quote: quote)

            return
        }

        pendingReveal = id
        pendingQuote = quote
        if window.focus(id) {
            reload()
        } else {
            fetch(window.request(around: id), focus: id, keepsEnd: false)
        }
    }

    func savePosition() {
        let anchor = listView.isNearBottom && window.isAtEnd ? nil : firstVisibleMessageID().flatMap { id in
            listView.anchor(for: id)
        }
        positions?.set(anchor, for: chatID)
    }

    func isAboveVisible(_ id: String) -> Bool {
        if let frame = listView.frame(for: id) {
            return frame.minY < listView.visibleContentRect.minY
        }

        let first = window.itemMessages.first
        let message = window.message(id)
        guard let first, let message else {
            return true
        }

        return message.date < first.date
    }

    func reportBottomState() {
        if listView.isNearBottom, window.isAtEnd {
            unseen = 0
        }
        let isFar = listView.distanceToBottom > Self.scrollDownDistance || !window.isAtEnd
        onBottomState?(isFar || unseen > 0, unseen)
    }

    private func firstVisibleMessageID() -> String? {
        listView.visibleItemIDs.first { id in
            window.index(of: id) != nil
        }
    }

    private func visibleRange() -> Range<Int>? {
        let indices = listView.visibleItemIDs.compactMap { id in
            window.index(of: id)
        }
        guard let lower = indices.min(), let upper = indices.max() else {
            return nil
        }

        return lower..<(upper + 1)
    }
}
