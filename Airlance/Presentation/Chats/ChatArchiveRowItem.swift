@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct ChatArchiveRowItem: AsyncListItem {
    let title: String
    let chats: [ChatSummary]
    let onSelect: @MainActor @Sendable () -> Void

    var id: String {
        "archive"
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(summary.message)
        hasher.combine(summary.unread)

        return hasher.finalize()
    }

    nonisolated private var summary: ChatSummary {
        let latest = chats.max { lhs, rhs in
            lhs.activityDate < rhs.activityDate
        }

        return ChatSummary(
            id: "archive",
            name: title,
            kind: .group,
            message: chats.map(\.name).joined(separator: ", "),
            date: latest?.activityDate ?? .distantPast,
            unread: chats.filter(\.hasUnread).count
        )
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        ChatRowLayout.height(theme: theme)
    }

    func makeNode() -> ListItemNode {
        ChatArchiveRowNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? ChatArchiveRowNode)?.update(theme: theme)
    }

    func selected() {
        onSelect()
    }

    nonisolated func prepareLayout(width: CGFloat, theme: ListTheme, displayScale: CGFloat) -> any ListPreparedLayout {
        ChatRowLayout(chat: summary, timeText: "", width: width, theme: theme, grayBadge: true)
    }

    func apply(_ layout: any ListPreparedLayout, to node: ListItemNode) {
        guard let layout = layout as? ChatRowLayout else {
            return
        }

        (node as? ChatArchiveRowNode)?.apply(layout)
    }
}

final class ChatArchiveRowNode: ListItemNode {
    private let circle = ASDisplayNode()
    private let icon = ASImageNode()
    private let separator = ASDisplayNode()
    private let content = ListRowCanvas()

    override func didLoad() {
        super.didLoad()
        circle.isLayerBacked = true
        icon.isLayerBacked = true
        icon.contentMode = .center
        separator.isLayerBacked = true
        addSubnode(circle)
        addSubnode(icon)
        addSubnode(separator)
        addSubnode(content)
    }

    func update(theme: ListTheme) {
        backgroundColor = theme.rowBackground
        circle.backgroundColor = theme.secondary.withAlphaComponent(0.55)
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        icon.image = UIImage(systemName: "archivebox.fill", withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        separator.backgroundColor = theme.separator
        setNeedsLayout()
    }

    func apply(_ layout: ChatRowLayout) {
        content.frame = CGRect(origin: .zero, size: layout.content.size)
        content.apply(layout.content)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        content.apply(nil)
    }

    override func layout() {
        super.layout()
        let size = ChatRowLayout.avatarSize
        circle.frame = CGRect(x: ChatRowLayout.avatarX, y: (bounds.height - size) / 2, width: size, height: size)
        circle.cornerRadius = size / 2
        icon.frame = circle.frame

        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: 0, y: bounds.height - line, width: bounds.width, height: line)
    }
}
