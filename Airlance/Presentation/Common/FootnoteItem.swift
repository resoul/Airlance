@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct FootnoteItem: ListItem {
    let id: String
    let text: String

    var version: Int {
        text.hashValue
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: max(1, width - 64), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: Self.font(theme)],
            context: nil
        )

        return (bounds.height + 18).rounded(.up)
    }

    func makeNode() -> ListItemNode {
        FootnoteNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? FootnoteNode)?.update(text: text, font: Self.font(theme), theme: theme)
    }

    static func font(_ theme: ListTheme) -> UIFont {
        .systemFont(ofSize: theme.subtitleFont.pointSize - 2)
    }
}

final class FootnoteNode: ListItemNode {
    private let label = ASTextNode()

    override func didLoad() {
        super.didLoad()
        label.isLayerBacked = true
        addSubnode(label)
    }

    func update(text: String, font: UIFont, theme: ListTheme) {
        backgroundColor = theme.background
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: theme.secondary]
        )
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        label.frame = CGRect(x: 32, y: 6, width: max(1, bounds.width - 64), height: max(1, bounds.height - 12))
    }
}
