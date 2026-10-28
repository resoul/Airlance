import AirlanceUI
import ChatFolders
import ListUI
import ToastUI
import UIKit

extension ChatsViewController {
    func render() {
        guard isViewLoaded else {
            return
        }

        updatePages(Self.pages(for: dependencies.chatFolders.list))
        let chats = dependencies.chatsStore.chats.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }

            return lhs.date > rhs.date
        }

        var tabItems: [LiquidTab] = []
        for (index, page) in pages.enumerated() {
            let pageChats = chats.filter { chat in
                contains(chat, in: page)
            }
            tabItems.append(tab(for: page, chats: pageChats))
            if pager.lists.indices.contains(index) {
                pager.lists[index].apply(items: items(for: pageChats, page: page), animated: false)
            }
        }
        tabs.setTabs(tabItems)
    }

    private static func pages(for list: ChatFolderList) -> [ChatsPage] {
        var pages = list.folders.map(ChatsPage.folder)
        pages.insert(.all, at: min(list.allChatsPosition, pages.count))

        return pages
    }

    private func updatePages(_ next: [ChatsPage]) {
        let previousIDs = pages.map(\.id)
        let selectedID = pages.indices.contains(pager.selectedIndex) ? pages[pager.selectedIndex].id : "all"
        pages = next
        guard next.map(\.id) != previousIDs else {
            return
        }

        pager.setPageCount(next.count)
        bindLists()
        tabs.isHidden = !hasFolders
        let index = next.firstIndex { page in
            page.id == selectedID
        } ?? next.firstIndex(of: .all) ?? 0
        pager.select(index, animated: false)
        tabs.select(index, animated: false)
        trackCurrentList()
        view.setNeedsLayout()
    }

    private func contains(_ chat: ChatSummary, in page: ChatsPage) -> Bool {
        switch page {
        case .all:
            true
        case .folder(let folder):
            folder.contains(chat)
        }
    }

    private func tab(for page: ChatsPage, chats: [ChatSummary]) -> LiquidTab {
        switch page {
        case .all:
            return LiquidTab(title: presentation.strings.chatsFolderAll)
        case .folder(let folder):
            let unread = chats.filter(\.hasUnread).count
            let title = folder.emoji.map { emoji in
                "\(emoji) \(folder.name)"
            } ?? folder.name

            return LiquidTab(title: title, badge: unread)
        }
    }

    private func items(for chats: [ChatSummary], page: ChatsPage) -> [any ListItem] {
        let strings = presentation.strings
        guard !chats.isEmpty else {
            return [ChatsEmptyItem(id: "empty", title: strings.chatsEmptyTitle, text: strings.chatsEmptyText)]
        }

        let now = Date()
        let stories = dependencies.storiesStore
        let swipes = !hasFolders

        return chats.map { chat in
            ChatRowItem(
                chat: chat,
                timeText: dateFormatter.string(for: chat.date, now: now),
                story: stories.story(for: chat.id),
                swipe: swipes ? swipeActions(for: chat) : nil
            )
        }
    }

    private func swipeActions(for chat: ChatSummary) -> ListSwipeActions {
        let strings = presentation.strings
        let store = dependencies.chatsStore
        let id = chat.id
        let read = ListSwipeAction(
            title: chat.hasUnread ? strings.chatsActionRead : strings.chatsActionUnread,
            symbol: chat.hasUnread ? "checkmark.message.fill" : "message.badge.fill",
            color: presentation.theme.colors.accent
        ) {
            store.toggleRead(id)
        }
        let pin = ListSwipeAction(
            title: chat.isPinned ? strings.chatsActionUnpin : strings.chatsActionPin,
            symbol: chat.isPinned ? "pin.slash.fill" : "pin.fill",
            color: .systemGreen
        ) {
            store.togglePin(id)
        }
        let muteToast = chat.isMuted ? strings.chatsToastUnmuted : strings.chatsToastMuted
        let muteSymbol = chat.isMuted ? "bell.fill" : "bell.slash.fill"
        let mute = ListSwipeAction(
            title: chat.isMuted ? strings.chatsActionUnmute : strings.chatsActionMute,
            symbol: muteSymbol,
            color: .systemOrange
        ) { [weak self] in
            store.toggleMute(id)
            self?.showToast(Toast(muteToast, symbol: muteSymbol))
        }
        let deleteToast = strings.chatsToastDeleted
        let delete = ListSwipeAction(
            title: strings.chatsActionDelete,
            symbol: "trash.fill",
            color: .systemRed
        ) { [weak self] in
            store.delete(id)
            self?.showToast(Toast(deleteToast, symbol: "trash.fill", style: .success, edge: .bottom))
        }

        return ListSwipeActions(leading: [read, pin], trailing: [mute, delete])
    }

    private func showToast(_ toast: Toast) {
        toast.show(theme: presentation.theme, in: view)
    }
}
