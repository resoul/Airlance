import ChatHistory
import ListUI
import Observers
import UIKit

@MainActor
final class ChatHistoryController {
    static let scrollDownDistance: CGFloat = 220

    let listView = ListView(theme: ListTheme())
    var onBottomState: (@MainActor (_ isShown: Bool, _ unseen: Int) -> Void)?
    var onMessageMenu: (@MainActor (HistoryMessage, MessageBubbleNode) -> Void)?
    var onPhotos: (@MainActor (HistoryMessage, Int, MessageBubbleNode) -> Void)?
    var onOpenURL: (@MainActor (URL) -> Void)?
    var onOpenFile: (@MainActor (MessageFile) -> Void)?
    var onUpdate: (@MainActor () -> Void)?
    var isReadOnly = false
    var window = HistoryWindow()
    var pendingReveal: String?
    var scrollsToBottom = false
    var unseen = 0
    var requestRevision = 0
    var isRequesting = false
    var hasData = false
    var metrics: HistoryMetrics?
    private(set) var isPreparing = false
    private(set) var style: HistoryStyle?

    let store: ChatHistoryStore
    let positions: ChatScrollPositions?
    private(set) var chatID = ""
    private var observation: ObservationToken?
    private var showsNames = false
    private var showsAvatars = false
    private var revision = 0
    private var width: CGFloat = 0
    private var titles: HistorySnapshot.Titles?
    private var locale = Locale.current
    private var layouts = LayoutCache()
    let avatars = StickyAvatars()
    let fileDownloads = FileDownloads()
    private(set) lazy var replySwipe = MessageReplySwipe(list: listView)
    let voicePlayback = VoicePlayback()

    init(store: ChatHistoryStore, positions: ChatScrollPositions? = nil) {
        self.store = store
        self.positions = positions
        listView.anchorsToBottom = true
        listView.scrollView.keyboardDismissMode = .interactive
        listView.onScroll = { [weak self] list in
            self?.scrolled(list)
        }
        listView.onContentSizeChange = { [weak self] list in
            self?.avatars.update(in: list)
        }
        bindVoice()
    }

    func load(_ id: String, chat: ChatSummary?) {
        chatID = id
        showsNames = chat?.kind == .group
        showsAvatars = chat.map { chat in
            chat.kind != .person
        } ?? false
        observation = store.observeHistory { [weak self] event in
            if event.chatID == self?.chatID {
                self?.historyChanged(event)
            }
        }
        if let anchor = positions?.anchor(for: id) {
            listView.scroll(to: anchor)
            fetch(window.request(around: anchor.id), focus: anchor.id, keepsEnd: false)
        } else {
            fetch(window.latestRequest, focus: nil, keepsEnd: true)
        }
    }

    func apply(_ presentation: PresentationData) {
        let theme = presentation.theme
        let strings = presentation.strings
        style = HistoryStyle(theme: theme)
        titles = HistorySnapshot.Titles(strings: strings)
        locale = strings.pack.locale
        if !isReadOnly {
            replySwipe.apply(theme)
        }
        listView.theme = ListTheme(
            background: theme.colors.background,
            rowBackground: .clear,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.caption
        )
        reload()
    }

    func setWidth(_ width: CGFloat) {
        guard width != self.width else {
            return
        }

        self.width = width
        reload()
    }

    func layoutChanged() {
        avatars.update(in: listView)
        if !isReadOnly {
            replySwipe.layout()
        }
    }

    func send(_ text: String, replyTo: HistoryMessage?) {
        scrollsToBottom = true
        store.send(text, to: chatID, replyTo: replyTo)
    }

    func sendVoice(_ voice: MessageVoice, replyTo: HistoryMessage?) {
        scrollsToBottom = true
        store.sendVoice(voice, to: chatID, replyTo: replyTo)
    }

    func forward(_ message: HistoryMessage, authorName: String, to target: String) {
        store.forward(message, authorName: authorName, to: target)
    }

    func deleteMessage(_ messageID: String) {
        store.delete(messageID, from: chatID)
    }

    func photoTapped(_ messageID: String, index: Int, node: MessageBubbleNode) {
        if let message = message(messageID) {
            onPhotos?(message, index, node)
        }
    }

    func message(_ id: String) -> HistoryMessage? {
        window.message(id)
    }

    func longPressed(_ messageID: String, node: MessageBubbleNode) {
        if let message = message(messageID) {
            onMessageMenu?(message, node)
        }
    }

    var pinnedIDs: [String] {
        window.data.pinned.map(\.id)
    }

    func markListened(_ messageID: String) {
        store.update(messageID, in: chatID) { message in
            message.isListened = true
        }
    }

    func setPinned(_ isPinned: Bool, messageID: String) {
        store.setPinned(isPinned, messageID: messageID, in: chatID)
    }

    func reload(animated: Bool = false) {
        guard hasData, let style, let titles, width > 0 else {
            return
        }

        revision += 1
        let revision = revision
        let request = HistorySnapshot.Request(
            messages: Array(window.itemMessages),
            contextBefore: window.contextBefore,
            contextAfter: window.contextAfter,
            unreadFrom: window.data.unreadFrom,
            showsNames: showsNames,
            showsAvatars: showsAvatars,
            width: width,
            scale: listView.view.traitCollection.displayScale,
            style: style,
            locale: locale,
            titles: titles,
            previous: layouts.storage
        )
        isPreparing = true
        Task { [weak self] in
            let (snapshot, duration) = await Task.detached(priority: .userInitiated) {
                let state = HistorySignpost.signposter.beginInterval("snapshot")
                let start = CACurrentMediaTime()
                let snapshot = HistorySnapshot(request)
                HistorySignpost.signposter.endInterval("snapshot", state)

                return (snapshot, CACurrentMediaTime() - start)
            }.value
            guard let self, self.revision == revision else {
                return
            }

            self.metrics?.record(.snapshot, seconds: duration)
            self.show(snapshot, style: style, animated: animated)
        }
    }

    private func show(_ snapshot: HistorySnapshot, style: HistoryStyle, animated: Bool) {
        isPreparing = false
        if let metrics {
            let reused = snapshot.layouts.filter { id, layout in
                layouts.storage[id] === layout
            }.count
            metrics.recordSnapshot(built: snapshot.layouts.count - reused, reused: reused)
        }
        layouts.merge(snapshot.layouts)
        listView.keepsBottomOnApply = window.isAtEnd
        let state = HistorySignpost.signposter.beginInterval("apply")
        let start = CACurrentMediaTime()
        listView.apply(items: items(snapshot, style: style), animated: animated)
        avatars.setSeries(snapshot.series, in: listView)
        HistorySignpost.signposter.endInterval("apply", state)
        metrics?.record(.apply, seconds: CACurrentMediaTime() - start)
        metrics?.recordWindow(
            total: store.messageCount(in: chatID),
            data: window.data.messages.count,
            items: window.items.count
        )
        reportBottomState()
        revealPending()
        onUpdate?()
        if scrollsToBottom, window.isAtEnd {
            scrollsToBottom = false
            listView.scrollToBottom(animated: true)
        }
    }
}

struct LayoutCache {
    private static let limit = 400

    private(set) var storage: [String: MessageBubbleLayout] = [:]
    private var order: [String] = []

    mutating func merge(_ layouts: [String: MessageBubbleLayout]) {
        let current = Set(layouts.keys)
        order = order.filter { id in
            !current.contains(id)
        } + layouts.keys
        storage.merge(layouts) { _, new in
            new
        }
        while order.count > Self.limit {
            storage[order.removeFirst()] = nil
        }
    }
}
