@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct ChatsEmptyItem: ListItem {
    let id: String
    let title: String
    let text: String

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(text)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        220
    }

    func makeNode() -> ListItemNode {
        ChatsEmptyNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? ChatsEmptyNode)?.update(title: title, text: text, theme: theme)
    }
}

final class ChatsEmptyNode: ListItemNode {
    private let icon = ASImageNode()
    private let titleNode = ASTextNode()
    private let textNode = ASTextNode()

    override func didLoad() {
        super.didLoad()
        icon.isLayerBacked = true
        icon.contentMode = .scaleAspectFit
        titleNode.isLayerBacked = true
        textNode.isLayerBacked = true
        addSubnode(icon)
        addSubnode(titleNode)
        addSubnode(textNode)
    }

    func update(title: String, text: String, theme: ListTheme) {
        backgroundColor = theme.background
        let symbol = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        icon.image = UIImage(systemName: "folder", withConfiguration: symbol)?
            .withTintColor(theme.secondary, renderingMode: .alwaysOriginal)
        let center = NSMutableParagraphStyle()
        center.alignment = .center
        titleNode.attributedText = NSAttributedString(
            string: title,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.primary, .paragraphStyle: center]
        )
        textNode.attributedText = NSAttributedString(
            string: text,
            attributes: [.font: theme.subtitleFont, .foregroundColor: theme.secondary, .paragraphStyle: center]
        )
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let width = bounds.width - 64
        icon.frame = CGRect(x: (bounds.width - 56) / 2, y: 40, width: 56, height: 56)
        let titleSize = titleNode.layoutThatFits(ASSizeRange(min: .zero, max: CGSize(width: width, height: 60))).size
        titleNode.frame = CGRect(x: 32, y: icon.frame.maxY + 16, width: width, height: titleSize.height)
        let textSize = textNode.layoutThatFits(ASSizeRange(min: .zero, max: CGSize(width: width, height: 80))).size
        textNode.frame = CGRect(x: 32, y: titleNode.frame.maxY + 6, width: width, height: textSize.height)
    }
}
