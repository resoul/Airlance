@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct ActionRowItem: ListItem {
    let id: String
    let title: String
    let symbol: String
    let onSelect: @MainActor () -> Void

    var version: Int {
        title.hashValue
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        max(52, (theme.titleFont.lineHeight + 24).rounded(.up))
    }

    func makeNode() -> ListItemNode {
        ActionRowNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? ActionRowNode)?.update(title: title, symbol: symbol, theme: theme)
    }

    func selected() {
        onSelect()
    }
}

final class ActionRowNode: ListItemNode {
    private let icon = ASImageNode()
    private let label = ASTextNode()
    private let separator = ASDisplayNode()

    override func didLoad() {
        super.didLoad()
        icon.contentMode = .center
        label.maximumNumberOfLines = 1
        addSubnode(icon)
        addSubnode(label)
        addSubnode(separator)
    }

    func update(title: String, symbol: String, theme: ListTheme) {
        backgroundColor = theme.rowBackground
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        icon.image = UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(theme.accent, renderingMode: .alwaysOriginal)
        label.attributedText = NSAttributedString(
            string: title,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.accent]
        )
        separator.backgroundColor = theme.separator
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let textX: CGFloat = 72
        icon.frame = CGRect(x: 16, y: 0, width: 44, height: bounds.height)

        let range = ASSizeRange(min: .zero, max: CGSize(width: bounds.width - textX - 16, height: bounds.height))
        let size = label.layoutThatFits(range).size
        label.frame = CGRect(x: textX, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)

        let line = 1 / view.traitCollection.displayScale
        separator.frame = CGRect(x: textX, y: bounds.height - line, width: bounds.width - textX, height: line)
    }
}
