import AirlanceUI
import ChatHistory
import Observers
import UIKit

@MainActor
final class QuickReplyPresenter {
    static let replyingChanged = Notification.Name("QuickReplyPresenter.replyingChanged")
    static let isReplyingKey = "isReplying"

    private weak var window: UIWindow?
    private let historyStore: ChatHistoryStore
    private let presentationContext: PresentationContext
    private let router: AppRouter
    private var observation: ObservationToken?
    private weak var card: QuickReplyCardView?
    private var cardChatID: String?
    private var history: ChatHistoryController?
    private var isClosed = false

    init(
        window: UIWindow,
        historyStore: ChatHistoryStore,
        presentationContext: PresentationContext,
        router: AppRouter
    ) {
        self.window = window
        self.historyStore = historyStore
        self.presentationContext = presentationContext
        self.router = router
        observation = historyStore.observeIncoming { [weak self] incoming in
            self?.show(incoming)
        }
    }

    func close() {
        isClosed = true
        observation = nil
        if let card, card.isActive {
            card.isUserInteractionEnabled = false
            card.dismiss()
        }
        card = nil
        cardChatID = nil
        history = nil
        NotificationCenter.default.post(
            name: Self.replyingChanged,
            object: window,
            userInfo: [Self.isReplyingKey: false]
        )
    }

    private func show(_ incoming: IncomingMessage) {
        guard
            !isClosed,
            let window,
            UIApplication.shared.applicationState == .active,
            !window.hasFocusOverlay,
            let chat = historyStore.chatsStore.chat(incoming.chatID)
        else {
            return
        }

        let text = messageText(incoming.message, in: chat)
        if let card, card.isActive {
            guard !card.isReplying else {
                return
            }

            if cardChatID == chat.id {
                card.update(message: text)

                return
            }

            card.dismiss()
        }
        let card = QuickReplyCardView(content(for: chat, text: text))
        bind(card, chatID: chat.id)
        card.start(in: window)
        self.card = card
        cardChatID = chat.id
    }

    private func bind(_ card: QuickReplyCardView, chatID: String) {
        let store = historyStore
        card.onSend = { text in
            store.send(text, to: chatID)
        }
        card.onPrepareHistory = { [weak self] in
            guard let self, !self.isClosed else {
                return nil
            }

            return self.makeHistory(chatID: chatID)
        }
        card.onReplyingChanged = { [weak window] isReplying in
            NotificationCenter.default.post(
                name: Self.replyingChanged,
                object: window,
                userInfo: [Self.isReplyingKey: isReplying]
            )
        }
        card.onOpenChat = { [weak self, weak card] _ in
            card?.dismiss()
            guard let self, !self.isClosed else {
                return
            }

            self.router.show(.chat(chatID))
        }
        card.onFinish = { [weak self] draft in
            store.chatsStore.setDraft(draft, for: chatID)
            if self?.cardChatID == chatID {
                self?.history = nil
                self?.cardChatID = nil
            }
        }
    }

    private func content(for chat: ChatSummary, text: String) -> QuickReplyCardContent {
        let strings = presentationContext.presentation.strings

        return QuickReplyCardContent(
            title: chat.name,
            message: text,
            draft: chat.draft ?? "",
            avatar: AvatarHostView(PeerAvatars.descriptor(id: chat.id, name: chat.name)),
            placeholder: strings.chatQuickReply,
            pullHint: strings.chatQuickReplyPull,
            releaseHint: strings.chatQuickReplyRelease,
            closeLabel: strings.chatQuickReplyClose
        )
    }

    private func messageText(_ message: HistoryMessage, in chat: ChatSummary) -> String {
        let strings = presentationContext.presentation.strings
        let text = MessageSnippet.text(message.content, strings: strings)

        return chat.kind == .group ? "\(message.authorName): \(text)" : text
    }

    private func makeHistory(chatID: String) -> UIView? {
        guard let window, let chat = historyStore.chatsStore.chat(chatID) else {
            return nil
        }

        let controller = ChatHistoryController(store: historyStore)
        controller.isReadOnly = true
        controller.listView.contentInsets = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        controller.load(chatID, kind: chat.kind)
        controller.apply(presentationContext.presentation)
        controller.setWidth(min(430, window.bounds.width - 28))
        history = controller

        return controller.listView.view
    }
}
