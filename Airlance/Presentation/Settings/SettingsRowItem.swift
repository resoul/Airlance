@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

enum CardPosition: Hashable {
    case single
    case first
    case middle
    case last
}

struct SettingsRowItem: ListItem {
    let id: String
    let title: String
    let symbol: String
    let color: UIColor
    var detail: String?
    let position: CardPosition
    var onSelect: (@MainActor () -> Void)?

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(symbol)
        hasher.combine(detail)
        hasher.combine(position)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        max(52, (theme.titleFont.lineHeight + 26).rounded(.up))
    }

    func makeNode() -> ListItemNode {
        SettingsRowNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? SettingsRowNode)?.update(self, theme: theme)
    }

    func selected() {
        onSelect?()
    }
}

final class SettingsRowNode: ListItemNode {
    private let card = ASDisplayNode()
    private let iconBackground = ASDisplayNode()
    private let icon = ASImageNode()
    private let title = ASTextNode()
    private let detail = ASTextNode()
    private let chevron = ASImageNode()
    private let separator = ASDisplayNode()
    private var cardPosition = CardPosition.single

    override func didLoad() {
        super.didLoad()
        for node in [card, iconBackground, icon, title, detail, chevron, separator] {
            node.isLayerBacked = true
        }
        title.maximumNumberOfLines = 1
        detail.maximumNumberOfLines = 1
        icon.contentMode = .center
        chevron.contentMode = .center
        addSubnode(card)
        card.addSubnode(iconBackground)
        card.addSubnode(icon)
        card.addSubnode(title)
        card.addSubnode(detail)
        card.addSubnode(chevron)
        card.addSubnode(separator)
    }

    func update(_ item: SettingsRowItem, theme: ListTheme) {
        backgroundColor = theme.background
        cardPosition = item.position
        card.backgroundColor = theme.rowBackground
        iconBackground.backgroundColor = item.color
        icon.image = UIImage(
            systemName: item.symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        )?.withTintColor(.white, renderingMode: .alwaysOriginal)
        title.attributedText = NSAttributedString(
            string: item.title,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.primary]
        )
        detail.attributedText = NSAttributedString(
            string: item.detail ?? "",
            attributes: [.font: theme.titleFont, .foregroundColor: theme.secondary]
        )
        chevron.image = UIImage(
            systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )?.withTintColor(theme.secondary.withAlphaComponent(0.6), renderingMode: .alwaysOriginal)
        separator.backgroundColor = theme.separator
        separator.isHidden = cardPosition == .single || cardPosition == .last
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        card.frame = bounds.insetBy(dx: 16, dy: 0)
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.layer.maskedCorners = cardCorners

        let size = card.bounds.size
        iconBackground.frame = CGRect(x: 14, y: (size.height - 30) / 2, width: 30, height: 30)
        iconBackground.layer.cornerRadius = 8
        iconBackground.layer.cornerCurve = .continuous
        icon.frame = iconBackground.frame
        chevron.frame = CGRect(x: size.width - 28, y: 0, width: 16, height: size.height)

        let textX: CGFloat = 58
        let detailRange = ASSizeRange(min: .zero, max: CGSize(width: size.width / 2, height: 40))
        let detailSize = detail.layoutThatFits(detailRange).size
        detail.frame = CGRect(
            x: chevron.frame.minX - 8 - detailSize.width,
            y: (size.height - detailSize.height) / 2,
            width: detailSize.width,
            height: detailSize.height
        )
        let titleWidth = max(0, detail.frame.minX - 8 - textX)
        let titleRange = ASSizeRange(min: .zero, max: CGSize(width: titleWidth, height: 40))
        let titleSize = title.layoutThatFits(titleRange).size
        let titleY = (size.height - titleSize.height) / 2
        title.frame = CGRect(x: textX, y: titleY, width: titleWidth, height: titleSize.height)

        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: textX, y: size.height - line, width: size.width - textX, height: line)
    }

    private var cardCorners: CACornerMask {
        let top: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let bottom: CACornerMask = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        switch cardPosition {
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
