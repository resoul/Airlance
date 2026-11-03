@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct TabRowItem: ListItem {
    enum Control: Hashable {
        case remove
        case add
        case locked
    }

    let id: String
    let title: String
    let detail: String?
    let image: UIImage?
    let control: Control
    let isMovable: Bool
    var position: CardPosition
    let onToggle: @MainActor () -> Void

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(detail)
        hasher.combine(image.map(ObjectIdentifier.init))
        hasher.combine(control)
        hasher.combine(isMovable)
        hasher.combine(position)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        max(56, (theme.titleFont.lineHeight + 30).rounded(.up))
    }

    func makeNode() -> ListItemNode {
        TabRowNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? TabRowNode)?.update(self, theme: theme)
    }

    func selected() {
        if control != .locked {
            onToggle()
        }
    }
}

final class TabRowNode: ListItemNode {
    private let card = ASDisplayNode()
    private let control = ASImageNode()
    private let icon = ASImageNode()
    private let title = ASTextNode()
    private let detail = ASTextNode()
    private let handle = ASImageNode()
    private let separator = ASDisplayNode()
    private var cardPosition = CardPosition.single

    override func didLoad() {
        super.didLoad()
        for node in [card, control, icon, title, detail, handle, separator] {
            node.isLayerBacked = true
        }
        for node in [control, icon, handle] {
            node.contentMode = .center
        }
        title.maximumNumberOfLines = 1
        detail.maximumNumberOfLines = 1
        addSubnode(card)
        for node in [control, icon, title, detail, handle, separator] {
            card.addSubnode(node)
        }
    }

    func update(_ item: TabRowItem, theme: ListTheme) {
        backgroundColor = theme.background
        cardPosition = item.position
        card.backgroundColor = theme.rowBackground
        control.image = Self.controlImage(item.control, theme: theme)
        icon.image = item.image.map { image in
            image.isSymbolImage ? image.withTintColor(theme.accent, renderingMode: .alwaysOriginal) : image
        }
        title.attributedText = NSAttributedString(
            string: item.title,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.primary]
        )
        detail.attributedText = item.detail.map { text in
            NSAttributedString(string: text, attributes: [
                .font: UIFont.systemFont(ofSize: theme.subtitleFont.pointSize - 2),
                .foregroundColor: theme.secondary,
            ])
        }
        handle.image = item.isMovable
            ? ListRowSymbols.image("line.3.horizontal", size: 17, color: theme.secondary.withAlphaComponent(0.7))
            : nil
        separator.backgroundColor = theme.separator
        separator.isHidden = cardPosition == .single || cardPosition == .last
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        card.frame = bounds.insetBy(dx: 16, dy: 0)
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.layer.maskedCorners = Self.corners(cardPosition)
        let size = card.bounds.size
        control.frame = CGRect(x: 8, y: 0, width: 36, height: size.height)
        icon.frame = CGRect(x: 44, y: 0, width: 32, height: size.height)
        handle.frame = CGRect(x: size.width - 44, y: 0, width: 36, height: size.height)
        let textX: CGFloat = 84
        let width = max(1, handle.frame.minX - textX - 4)
        let range = ASSizeRange(min: .zero, max: CGSize(width: width, height: 40))
        let titleSize = title.layoutThatFits(range).size
        let detailSize = (detail.attributedText?.length ?? 0) == 0 ? .zero : detail.layoutThatFits(range).size
        let top = (size.height - titleSize.height - detailSize.height) / 2
        title.frame = CGRect(x: textX, y: top, width: width, height: titleSize.height)
        detail.frame = CGRect(x: textX, y: title.frame.maxY, width: width, height: detailSize.height)
        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: textX, y: size.height - line, width: size.width - textX, height: line)
    }

    private static func controlImage(_ control: TabRowItem.Control, theme: ListTheme) -> UIImage {
        switch control {
        case .remove:
            ListRowSymbols.image("minus.circle.fill", size: 21, color: .systemRed)
        case .add:
            ListRowSymbols.image("plus.circle.fill", size: 21, color: .systemGreen)
        case .locked:
            ListRowSymbols.image("lock.fill", size: 15, color: theme.secondary)
        }
    }

    private static func corners(_ position: CardPosition) -> CACornerMask {
        let top: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let bottom: CACornerMask = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        switch position {
        case .single:
            return top.union(bottom)
        case .first:
            return top
        case .middle:
            return []
        case .last:
            return bottom
        }
    }
}
