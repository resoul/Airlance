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
    var typing: String?
    var messageText: String?
    var tags: [ChatRowTag] = []
    var onStory: (@MainActor (ChatRowNode) -> Void)?
    let onSelect: @MainActor () -> Void

    var id: String {
        chat.id
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(chat.name)
        hasher.combine(chat.message)
        hasher.combine(messageText)
        hasher.combine(tags)
        hasher.combine(chat.preview)
        hasher.combine(chat.isSending)
        hasher.combine(chat.isFailed)
        hasher.combine(chat.unreadMentions)
        hasher.combine(chat.unreadReactions)
        hasher.combine(chat.draft)
        hasher.combine(draft)
        hasher.combine(typing)
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

    func tapped(node: ListItemNode, at point: CGPoint) {
        guard let story, story.total > 0, let row = node as? ChatRowNode,
              row.avatarFrame.insetBy(dx: -6, dy: -6).contains(point) else {
            selected()

            return
        }

        onStory?(row)
    }

    func longPressed(node: ListItemNode, at point: CGPoint) {
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
        ChatRowLayout(
            chat: chat,
            timeText: timeText,
            width: width,
            theme: theme,
            draft: draft,
            typing: typing,
            messageText: messageText,
            tags: tags
        )
    }

    func apply(_ layout: any ListPreparedLayout, to node: ListItemNode) {
        guard let layout = layout as? ChatRowLayout else {
            return
        }

        (node as? ChatRowNode)?.apply(layout)
    }
}
