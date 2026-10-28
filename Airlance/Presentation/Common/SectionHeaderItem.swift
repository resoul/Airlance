@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct SectionHeaderItem: ListItem {
    let id: String
    let title: String

    var version: Int {
        title.hashValue
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        max(36, (theme.subtitleFont.lineHeight + 18).rounded(.up))
    }

    func makeNode() -> ListItemNode {
        SectionHeaderNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? SectionHeaderNode)?.update(title: title, theme: theme)
    }
}

final class SectionHeaderNode: ListItemNode {
    private let label = ASTextNode()

    override func didLoad() {
        super.didLoad()
        label.isLayerBacked = true
        label.maximumNumberOfLines = 1
        addSubnode(label)
    }

    func update(title: String, theme: ListTheme) {
        backgroundColor = theme.background
        label.attributedText = NSAttributedString(
            string: title.uppercased(),
            attributes: [.font: theme.subtitleFont, .foregroundColor: theme.secondary]
        )
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let range = ASSizeRange(min: .zero, max: CGSize(width: bounds.width - 32, height: bounds.height))
        let size = label.layoutThatFits(range).size
        label.frame = CGRect(x: 16, y: bounds.height - size.height - 6, width: size.width, height: size.height)
    }
}
