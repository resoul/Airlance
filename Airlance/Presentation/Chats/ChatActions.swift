import AirlanceUI
@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import ToastUI
import UIKit

@MainActor
struct ChatActions {
    let store: ChatsStore
    let presentation: PresentationData
    weak var host: UIView?

    func swipes(for chat: ChatSummary) -> ListSwipeActions {
        if chat.isArchived {
            return ListSwipeActions(leading: [read(chat)], trailing: [pin(chat), delete(chat), archive(chat)])
        }

        return ListSwipeActions(leading: [read(chat), pin(chat)], trailing: [mute(chat), delete(chat), archive(chat)])
    }

    func menu(for chat: ChatSummary) -> [ChatPeekView.Item] {
        let plain = [read(chat), pin(chat), mute(chat)].map { action in
            ChatPeekView.Item(action: action, isDestructive: false)
        }

        return plain + [
            ChatPeekView.Item(action: delete(chat), isDestructive: true),
            ChatPeekView.Item(action: archive(chat), isDestructive: false),
        ]
    }

    func confirmDelete(_ chat: ChatSummary) {
        guard let host else {
            return
        }

        let strings = presentation.strings
        let store = store
        let id = chat.id
        let deleted = Toast(strings.chatsToastDeleted, symbol: "trash.fill", style: .success, edge: .bottom)
        let theme = presentation.theme
        let remove = { @MainActor [weak host] in
            store.delete(id)
            if let host {
                deleted.show(theme: theme, in: host)
            }
        }
        var actions = [PopupAlertAction]()
        if chat.kind == .person {
            actions.append(PopupAlertAction(title: strings.chatsDeleteForMe, style: .destructive, handler: remove))
            actions.append(
                PopupAlertAction(title: strings.chatsDeleteForBoth(chat.name), style: .destructive, handler: remove)
            )
        } else {
            actions.append(PopupAlertAction(title: strings.chatsDeleteLeave, style: .destructive, handler: remove))
        }
        actions.append(PopupAlertAction(title: strings.chatsDeleteCancel, style: .cancel))
        PopupAlert.show(
            header: ChatAlertAvatarView(chat: chat),
            title: strings.chatsDeleteTitle,
            message: strings.chatsDeleteMessage(chat.name),
            actions: actions,
            theme: theme,
            in: host
        )
    }

    private func read(_ chat: ChatSummary) -> ListSwipeAction {
        let store = store
        let id = chat.id

        return ListSwipeAction(
            title: chat.hasUnread ? presentation.strings.chatsActionRead : presentation.strings.chatsActionUnread,
            symbol: chat.hasUnread ? "checkmark.message.fill" : "message.badge.fill",
            color: presentation.theme.colors.accent
        ) {
            store.toggleRead(id)
        }
    }

    private func pin(_ chat: ChatSummary) -> ListSwipeAction {
        let store = store
        let id = chat.id

        return ListSwipeAction(
            title: chat.isPinned ? presentation.strings.chatsActionUnpin : presentation.strings.chatsActionPin,
            symbol: chat.isPinned ? "pin.slash.fill" : "pin.fill",
            color: .systemGreen
        ) {
            store.togglePin(id)
        }
    }

    private func mute(_ chat: ChatSummary) -> ListSwipeAction {
        let strings = presentation.strings
        let symbol = chat.isMuted ? "bell.fill" : "bell.slash.fill"
        let toast = Toast(chat.isMuted ? strings.chatsToastUnmuted : strings.chatsToastMuted, symbol: symbol)

        return action(
            for: chat,
            title: chat.isMuted ? strings.chatsActionUnmute : strings.chatsActionMute,
            symbol: symbol,
            color: .systemOrange,
            toast: toast
        ) { store, id in
            store.toggleMute(id)
        }
    }

    private func archive(_ chat: ChatSummary) -> ListSwipeAction {
        let strings = presentation.strings
        let symbol = chat.isArchived ? "tray.and.arrow.up.fill" : "archivebox.fill"
        let toast = Toast(chat.isArchived ? strings.chatsToastUnarchived : strings.chatsToastArchived, symbol: symbol)

        return action(
            for: chat,
            title: chat.isArchived ? strings.chatsActionUnarchive : strings.chatsActionArchive,
            symbol: symbol,
            color: .systemGray,
            toast: toast
        ) { store, id in
            store.toggleArchive(id)
        }
    }

    private func delete(_ chat: ChatSummary) -> ListSwipeAction {
        let actions = self

        return ListSwipeAction(title: presentation.strings.chatsActionDelete, symbol: "trash.fill", color: .systemRed) {
            actions.confirmDelete(chat)
        }
    }

    private func action(
        for chat: ChatSummary,
        title: String,
        symbol: String,
        color: UIColor,
        toast: Toast,
        change: @escaping @MainActor @Sendable (ChatsStore, String) -> Void
    ) -> ListSwipeAction {
        let store = store
        let id = chat.id
        let theme = presentation.theme

        return ListSwipeAction(title: title, symbol: symbol, color: color) { [weak host] in
            change(store, id)
            if let host {
                toast.show(theme: theme, in: host)
            }
        }
    }
}

final class ChatAlertAvatarView: UIView {
    private static let size: CGFloat = 80

    private let avatar = AvatarNode()

    init(chat: ChatSummary) {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.size, height: Self.size))
        addSubnode(avatar)
        avatar.frame = bounds
        avatar.apply(PeerAvatars.descriptor(id: chat.id, name: chat.name))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
