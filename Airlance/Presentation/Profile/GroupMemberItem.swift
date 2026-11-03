@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

struct GroupMemberItem: ListItem {
    let member: GroupMember?
    let title: String
    let detail: String
    let badge: String?
    let symbol: String?
    let onSelect: @MainActor () -> Void

    var id: String {
        member.map { member in
            "member.\(member.id)"
        } ?? "member.permissions"
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(detail)
        hasher.combine(badge)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        max(60, (theme.titleFont.lineHeight + theme.subtitleFont.lineHeight + 22).rounded(.up))
    }

    func makeNode() -> ListItemNode {
        GroupMemberNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? GroupMemberNode)?.update(item: self, theme: theme)
    }

    func selected() {
        onSelect()
    }
}

final class GroupMemberNode: ListItemNode {
    private static let side: CGFloat = 42

    private let avatar = ASImageNode()
    private let heading = ASTextNode()
    private let detail = ASTextNode()
    private let badge = ASTextNode()
    private let separator = ASDisplayNode()

    override func didLoad() {
        super.didLoad()
        for node in [avatar, heading, detail, badge, separator] {
            node.isLayerBacked = true
            addSubnode(node)
        }
        avatar.cornerRadius = Self.side / 2
        avatar.clipsToBounds = true
        avatar.contentMode = .center
        heading.maximumNumberOfLines = 1
        heading.truncationMode = .byTruncatingTail
        detail.maximumNumberOfLines = 1
        detail.truncationMode = .byTruncatingTail
    }

    func update(item: GroupMemberItem, theme: ListTheme) {
        backgroundColor = theme.rowBackground
        if let member = item.member {
            avatar.backgroundColor = nil
            avatar.image = AvatarDescriptor(id: member.id, initials: AvatarDescriptor.initials(from: member.name))
                .placeholderImage(side: Self.side, scale: UIScreen.main.scale)
        } else {
            avatar.backgroundColor = theme.accent.withAlphaComponent(0.16)
            avatar.image = UIImage(systemName: item.symbol ?? "key.fill")?
                .withTintColor(theme.accent, renderingMode: .alwaysOriginal)
        }
        heading.attributedText = NSAttributedString(
            string: item.title,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.primary]
        )
        let isOnline = item.member?.isOnline == true
        detail.attributedText = NSAttributedString(
            string: item.detail,
            attributes: [.font: theme.subtitleFont, .foregroundColor: isOnline ? theme.accent : theme.secondary]
        )
        badge.attributedText = item.badge.map { text in
            NSAttributedString(string: text, attributes: [.font: theme.subtitleFont, .foregroundColor: theme.accent])
        }
        separator.backgroundColor = theme.separator
        isAccessibilityElement = true
        accessibilityLabel = [item.title, item.badge, item.detail].compactMap(\.self).joined(separator: ", ")
        accessibilityTraits = .button
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let side = Self.side
        avatar.frame = CGRect(x: 16, y: (bounds.height - side) / 2, width: side, height: side)
        let badgeSize = badge.attributedText?.size() ?? .zero
        badge.frame = CGRect(
            x: bounds.width - 16 - ceil(badgeSize.width),
            y: (bounds.height - ceil(badgeSize.height)) / 2,
            width: ceil(badgeSize.width),
            height: ceil(badgeSize.height)
        )
        let x = avatar.frame.maxX + 12
        let width = max(0, badge.frame.minX - x - 8)
        let headingHeight = ceil(heading.attributedText?.size().height ?? 0)
        let detailHeight = ceil(detail.attributedText?.size().height ?? 0)
        let top = (bounds.height - headingHeight - detailHeight - 2) / 2
        heading.frame = CGRect(x: x, y: top, width: width, height: headingHeight)
        detail.frame = CGRect(x: x, y: top + headingHeight + 2, width: width, height: detailHeight)
        separator.frame = CGRect(x: x, y: bounds.height - 0.5, width: max(0, bounds.width - x), height: 0.5)
    }
}
