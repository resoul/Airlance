import AirlanceUI
import ChatFolders
import ListUI
import UIKit

extension ChatsViewController {
    func render() {
        guard isViewLoaded else {
            return
        }

        updatePages(Self.pages(for: dependencies.chatFolders.list))
        let visible = dependencies.chatsStore.chats.filter { chat in
            !chat.isArchived
        }
        let chats = visible.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }

            return lhs.activityDate > rhs.activityDate
        }

        var tabItems: [LiquidTab] = []
        for (index, page) in pages.enumerated() {
            let pageChats = chats.filter { chat in
                contains(chat, in: page)
            }
            tabItems.append(tab(for: page, chats: pageChats))
            if pager.lists.indices.contains(index) {
                let list = pager.lists[index]
                list.onLongPressMove = { [weak self] gesture in
                    self?.trackPeek(gesture)
                }
                list.apply(items: items(for: pageChats, page: page), animated: false)
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
        let archived = page == .all ? dependencies.chatsStore.chats.filter(\.isArchived) : []
        var items: [any ListItem] = []
        if !archived.isEmpty {
            items.append(ChatArchiveRowItem(title: strings.chatsArchiveTitle, chats: archived) { [router] in
                router.open(.chatArchive)
            })
        }
        guard !chats.isEmpty || !items.isEmpty else {
            return [ChatsEmptyItem(id: "empty", title: strings.chatsEmptyTitle, text: strings.chatsEmptyText)]
        }

        let now = Date()
        let stories = dependencies.storiesStore
        let draft = ChatRowDraft(title: strings.chatsDraft, color: presentation.theme.colors.destructive)
        let actions = hasFolders
            ? nil
            : ChatActions(store: dependencies.chatsStore, presentation: presentation, host: view)

        return items + chats.map { chat in
            ChatRowItem(
                chat: chat,
                timeText: dateFormatter.string(for: chat.activityDate, now: now),
                story: stories.story(for: chat.id),
                swipe: actions?.swipes(for: chat),
                onPeek: { [weak self] node in
                    self?.peek(chat, from: node)
                },
                draft: draft,
                typing: chat.typing.map { name in
                    strings.typing(name)
                }
            ) { [router] in
                router.open(.chat(chat.id))
            }
        }
    }
}

extension ChatsViewController {
    func peek(_ chat: ChatSummary, from node: ListItemNode) {
        guard let host = view.window else {
            return
        }

        let actions = ChatActions(store: dependencies.chatsStore, presentation: presentation, host: view)
        let history = ChatHistoryController(store: dependencies.historyStore)
        history.isReadOnly = true
        let peek = ChatPeekView(
            chat: chat,
            history: history,
            items: actions.menu(for: chat),
            presentation: presentation,
            source: node.view.convert(node.bounds, to: host),
            host: host
        )
        peek.onOpen = { [router] in
            router.open(.chat(chat.id))
        }
        activePeek = peek
        peek.show()
    }

    private func trackPeek(_ gesture: UILongPressGestureRecognizer) {
        guard let peek = activePeek else {
            return
        }

        switch gesture.state {
        case .changed:
            peek.track(gesture.location(in: peek), ended: false)
        case .ended:
            peek.track(gesture.location(in: peek), ended: true)
        default:
            peek.track(CGPoint(x: -1, y: -1), ended: true)
        }
    }
}
