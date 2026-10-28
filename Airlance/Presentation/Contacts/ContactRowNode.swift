@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

final class ContactRowNode: ListItemNode {
    private let avatar = AvatarNode()
    private let separator = ASDisplayNode()
    private let check = ASImageNode()
    private var textNodes: [ASTextNode] = []

    override func didLoad() {
        super.didLoad()
        separator.isLayerBacked = true
        check.isLayerBacked = true
        check.contentMode = .center
        addSubnode(avatar)
        addSubnode(separator)
        addSubnode(check)
    }

    func update(avatar descriptor: AvatarDescriptor, showsSeparator: Bool, isSelected: Bool?, theme: ListTheme) {
        backgroundColor = theme.rowBackground
        avatar.apply(descriptor)
        separator.backgroundColor = theme.separator
        separator.isHidden = !showsSeparator
        check.isHidden = isSelected == nil
        if let isSelected {
            let symbol = isSelected ? "checkmark.circle.fill" : "circle"
            let color = isSelected ? theme.accent : theme.secondary
            let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
            check.image = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
        }
        setNeedsLayout()
    }

    func apply(_ layout: ContactRowLayout) {
        for node in textNodes {
            node.removeFromSupernode()
        }
        textNodes = [layout.title] + (layout.subtitle.map { node in
            [node]
        } ?? [])
        for node in textNodes {
            addSubnode(node)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.prepareForReuse()
        for node in textNodes {
            node.removeFromSupernode()
        }
        textNodes = []
    }

    override func layout() {
        super.layout()
        let size = ContactRowLayout.avatarSize
        let inset = ContactRowLayout.inset
        let textX = ContactRowLayout.textX
        avatar.frame = CGRect(x: inset, y: (bounds.height - size) / 2, width: size, height: size)
        check.frame = CGRect(x: bounds.width - inset - 28, y: 0, width: 28, height: bounds.height)

        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: textX, y: bounds.height - line, width: bounds.width - textX, height: line)
    }
}
