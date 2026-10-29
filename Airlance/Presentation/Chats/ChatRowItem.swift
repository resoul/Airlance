@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

struct ChatRowItem: AsyncListItem {
    let chat: ChatSummary
    let timeText: String
    let story: StorySummary?
    var swipe: ListSwipeActions?
    var onPeek: (@MainActor (ListItemNode) -> Void)?
    var draft: ChatRowDraft?
    let onSelect: @MainActor () -> Void

    var id: String {
        chat.id
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(chat.name)
        hasher.combine(chat.message)
        hasher.combine(chat.draft)
        hasher.combine(draft)
        hasher.combine(timeText)
        hasher.combine(chat.unread)
        hasher.combine(chat.isMuted)
        hasher.combine(chat.isPinned)
        hasher.combine(chat.outgoingRead)
        hasher.combine(chat.isOnline)
        hasher.combine(story?.unseen)

        return hasher.finalize()
    }

    func selected() {
        onSelect()
    }

    func longPressed(node: ListItemNode) {
        onPeek?(node)
    }

    func swipeActions() -> ListSwipeActions? {
        swipe
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        ChatRowLayout.height(theme: theme)
    }

    func makeNode() -> ListItemNode {
        ChatRowNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? ChatRowNode)?.update(
            avatar: PeerAvatars.descriptor(id: chat.id, name: chat.name),
            storyRing: PeerAvatars.storyRing(for: story, theme: theme),
            isOnline: chat.isOnline,
            theme: theme
        )
    }

    nonisolated func prepareLayout(width: CGFloat, theme: ListTheme, displayScale: CGFloat) -> any ListPreparedLayout {
        ChatRowLayout(chat: chat, timeText: timeText, width: width, theme: theme, draft: draft)
    }

    func apply(_ layout: any ListPreparedLayout, to node: ListItemNode) {
        guard let layout = layout as? ChatRowLayout else {
            return
        }

        (node as? ChatRowNode)?.apply(layout)
    }
}
