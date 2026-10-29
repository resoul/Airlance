@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

struct CallRowItem: AsyncListItem {
    let entry: CallEntry
    let subtitle: String
    let dateText: String
    let isEditing: Bool
    let showsSeparator: Bool
    let story: StorySummary?
    let onDelete: @MainActor () -> Void
    let onInfo: @MainActor () -> Void

    var id: String {
        entry.id
    }

    var layoutVersion: Int {
        var hasher = Hasher()
        hasher.combine(entry.name)
        hasher.combine(subtitle)
        hasher.combine(dateText)
        hasher.combine(entry.isMissed)

        return hasher.finalize()
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(layoutVersion)
        hasher.combine(entry.isOutgoing)
        hasher.combine(isEditing)
        hasher.combine(showsSeparator)
        hasher.combine(story?.unseen)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        CallRowLayout.height(theme: theme)
    }

    func makeNode() -> ListItemNode {
        CallRowNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        guard let node = node as? CallRowNode else {
            return
        }

        node.onDelete = onDelete
        node.onInfo = onInfo
        node.update(
            avatar: PeerAvatars.descriptor(id: entry.peerID, name: entry.name),
            storyRing: PeerAvatars.storyRing(for: story, theme: theme),
            isOutgoing: entry.isOutgoing,
            isEditing: isEditing,
            showsSeparator: showsSeparator,
            theme: theme
        )
    }

    nonisolated func prepareLayout(width: CGFloat, theme: ListTheme, displayScale: CGFloat) -> any ListPreparedLayout {
        CallRowLayout(
            name: entry.name,
            subtitle: subtitle,
            dateText: dateText,
            isMissed: entry.isMissed,
            width: width,
            theme: theme
        )
    }

    func apply(_ layout: any ListPreparedLayout, to node: ListItemNode) {
        guard let layout = layout as? CallRowLayout else {
            return
        }

        (node as? CallRowNode)?.apply(layout)
    }
}

final class CallRowLayout: ListPreparedLayout, @unchecked Sendable {
    static let editShift: CGFloat = 44
    static let avatarX: CGFloat = 36
    static let avatarSize: CGFloat = 44

    let text: ListRowContent
    let date: ListRowContent

    init(name: String, subtitle: String, dateText: String, isMissed: Bool, width: CGFloat, theme: ListTheme) {
        let dateString = Self.text(dateText, font: theme.subtitleFont, color: theme.secondary)
        let dateSize = ListRowContent.measure(dateString, width: 120, lines: 1)
        let textX = Self.avatarX + Self.editShift + Self.avatarSize + 12
        let textWidth = max(1, width - 16 - dateSize.width - 8 - textX)

        let titleColor = isMissed ? UIColor.systemRed : theme.primary
        let title = Self.text(name, font: theme.titleFont, color: titleColor)
        let detail = Self.text(subtitle, font: theme.subtitleFont, color: theme.secondary)
        let titleSize = ListRowContent.measure(title, width: textWidth, lines: 1)
        let detailSize = ListRowContent.measure(detail, width: textWidth, lines: 1)
        let detailFrame = CGRect(origin: CGPoint(x: 0, y: titleSize.height + 2), size: detailSize)

        text = ListRowContent(
            size: CGSize(width: textWidth, height: detailFrame.maxY),
            elements: [
                .text(title, lines: 1, frame: CGRect(origin: .zero, size: titleSize)),
                .text(detail, lines: 1, frame: detailFrame),
            ]
        )
        let dateFrame = CGRect(origin: .zero, size: dateSize)
        date = ListRowContent(size: dateSize, elements: [.text(dateString, lines: 1, frame: dateFrame)])
    }

    static func height(theme: ListTheme) -> CGFloat {
        max(64, (theme.titleFont.lineHeight + 2 + theme.subtitleFont.lineHeight + 22).rounded(.up))
    }

    private static func text(_ string: String, font: UIFont, color: UIColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }
}
