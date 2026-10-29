@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct ProfileAttachmentItem: ListItem {
    enum Kind: String, CaseIterable {
        case files
        case links
        case voice
    }

    let kind: Kind
    let index: Int
    let title: String
    let detail: String
    let onSelect: @MainActor (String) -> Void

    var id: String {
        "profile.\(kind.rawValue).\(index)"
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(detail)

        return hasher.finalize()
    }

    var symbol: String {
        switch kind {
        case .files:
            ["doc.fill", "doc.richtext.fill", "archivebox.fill"][index % 3]
        case .links:
            "link"
        case .voice:
            "play.fill"
        }
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        max(68, (theme.titleFont.lineHeight + theme.subtitleFont.lineHeight + 28).rounded(.up))
    }

    func makeNode() -> ListItemNode {
        ProfileAttachmentNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? ProfileAttachmentNode)?.update(item: self, theme: theme)
    }

    func selected() {
        onSelect(title)
    }
}

final class ProfileAttachmentNode: ListItemNode {
    private let tile = ASDisplayNode()
    private let icon = ASImageNode()
    private let heading = ASTextNode()
    private let detail = ASTextNode()
    private let separator = ASDisplayNode()

    override func didLoad() {
        super.didLoad()
        for node in [tile, icon, heading, detail, separator] {
            node.isLayerBacked = true
            addSubnode(node)
        }
        tile.cornerRadius = 12
        icon.contentMode = .scaleAspectFit
        heading.maximumNumberOfLines = 1
        heading.truncationMode = .byTruncatingTail
        detail.maximumNumberOfLines = 1
        detail.truncationMode = .byTruncatingTail
    }

    func update(item: ProfileAttachmentItem, theme: ListTheme) {
        backgroundColor = theme.rowBackground
        tile.backgroundColor = theme.accent.withAlphaComponent(0.16)
        icon.image = UIImage(systemName: item.symbol)?.withTintColor(theme.accent, renderingMode: .alwaysOriginal)
        heading.attributedText = NSAttributedString(
            string: item.title,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.primary]
        )
        detail.attributedText = NSAttributedString(
            string: item.detail,
            attributes: [.font: theme.subtitleFont, .foregroundColor: theme.secondary]
        )
        separator.backgroundColor = theme.separator
        isAccessibilityElement = true
        accessibilityLabel = "\(item.title), \(item.detail)"
        accessibilityTraits = .button
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let width = max(0, bounds.width - 94)
        let headingHeight = ceil(heading.attributedText?.size().height ?? 0)
        let detailHeight = ceil(detail.attributedText?.size().height ?? 0)
        let top = (bounds.height - headingHeight - detailHeight - 4) / 2
        tile.frame = CGRect(x: 16, y: (bounds.height - 48) / 2, width: 48, height: 48)
        icon.frame = tile.frame.insetBy(dx: 12, dy: 12)
        heading.frame = CGRect(x: 78, y: top, width: width, height: headingHeight)
        detail.frame = CGRect(x: 78, y: top + headingHeight + 4, width: width, height: detailHeight)
        separator.frame = CGRect(x: 78, y: bounds.height - 0.5, width: max(0, bounds.width - 78), height: 0.5)
    }
}
