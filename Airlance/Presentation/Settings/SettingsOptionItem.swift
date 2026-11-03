@preconcurrency import AsyncDisplayKit
import ListUI
import Theme
import UIKit

struct SettingsOptionItem: ListItem {
    enum Accessory: Hashable {
        case none
        case chevron
        case check(Bool)
        case toggle(Bool)
    }

    let id: String
    let title: String
    var subtitle: String?
    var detail: String?
    var symbol: String?
    var iconColor = UIColor.systemBlue
    var accessory = Accessory.none
    var isEnabled = true
    var isAction = false
    var position = CardPosition.single
    var onSelect: (@MainActor () -> Void)?
    var onToggle: (@MainActor (Bool) -> Void)?

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(detail)
        hasher.combine(symbol)
        hasher.combine(accessory)
        hasher.combine(isEnabled)
        hasher.combine(isAction)
        hasher.combine(position)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        let textWidth = max(1, width - 32 - textX - trailing)
        let title = Self.height(of: title, font: theme.titleFont, width: textWidth)
        guard let subtitle, !subtitle.isEmpty else {
            return max(52, (title + 26).rounded(.up))
        }

        let lines = Self.height(of: subtitle, font: theme.subtitleFont, width: textWidth)

        return max(60, (title + lines + 30).rounded(.up))
    }

    func makeNode() -> ListItemNode {
        SettingsOptionNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? SettingsOptionNode)?.update(self, theme: theme)
    }

    func selected() {
        guard isEnabled else {
            return
        }

        if case .toggle(let isOn) = accessory {
            onToggle?(!isOn)
        } else {
            onSelect?()
        }
    }

    var textX: CGFloat {
        symbol == nil ? 16 : 58
    }

    var trailing: CGFloat {
        switch accessory {
        case .toggle:
            86
        case .chevron:
            detail == nil ? 36 : 120
        case .check:
            40
        case .none:
            detail == nil ? 16 : 120
        }
    }

    static func height(of text: String, font: UIFont, width: CGFloat) -> CGFloat {
        (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height
    }
}

final class SettingsOptionNode: ListItemNode {
    private let card = ASDisplayNode()
    private let iconBackground = ASDisplayNode()
    private let icon = ASImageNode()
    private let title = ASTextNode()
    private let subtitle = ASTextNode()
    private let detail = ASTextNode()
    private let mark = ASImageNode()
    private let separator = ASDisplayNode()
    private let toggle = ASDisplayNode {
        UISwitch()
    }
    private var item: SettingsOptionItem?

    override func didLoad() {
        super.didLoad()
        for node in [card, iconBackground, icon, title, subtitle, detail, mark, separator] {
            node.isLayerBacked = true
            addSubnode(node)
        }
        title.maximumNumberOfLines = 2
        detail.maximumNumberOfLines = 1
        icon.contentMode = .center
        mark.contentMode = .center
        addSubnode(toggle)
        (toggle.view as? UISwitch)?.addAction(
            UIAction { [weak self] action in
                let isOn = (action.sender as? UISwitch)?.isOn ?? false
                self?.item?.onToggle?(isOn)
            },
            for: .valueChanged
        )
    }

    func update(_ item: SettingsOptionItem, theme: ListTheme) {
        self.item = item
        backgroundColor = theme.background
        card.backgroundColor = theme.rowBackground
        let alpha: CGFloat = item.isEnabled ? 1 : 0.45
        let titleColor = item.isAction ? theme.accent : theme.primary
        title.attributedText = NSAttributedString(
            string: item.title,
            attributes: [.font: theme.titleFont, .foregroundColor: titleColor.withAlphaComponent(alpha)]
        )
        subtitle.attributedText = item.subtitle.map { text in
            NSAttributedString(
                string: text,
                attributes: [.font: theme.subtitleFont, .foregroundColor: theme.secondary.withAlphaComponent(alpha)]
            )
        }
        detail.attributedText = NSAttributedString(
            string: item.detail ?? "",
            attributes: [.font: theme.titleFont, .foregroundColor: theme.secondary]
        )
        updateIcon(item, alpha: alpha)
        updateAccessory(item, theme: theme)
        separator.backgroundColor = theme.separator
        separator.isHidden = item.position == .single || item.position == .last
        setNeedsLayout()
    }

    private func updateIcon(_ item: SettingsOptionItem, alpha: CGFloat) {
        iconBackground.isHidden = item.symbol == nil
        icon.isHidden = item.symbol == nil
        iconBackground.backgroundColor = item.iconColor.withAlphaComponent(alpha)
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image = item.symbol.flatMap { symbol in
            UIImage(systemName: symbol, withConfiguration: configuration)
        }
        icon.image = image?.withTintColor(.white, renderingMode: .alwaysOriginal)
    }

    private func updateAccessory(_ item: SettingsOptionItem, theme: ListTheme) {
        let switchView = toggle.view as? UISwitch
        toggle.isHidden = true
        mark.isHidden = true
        switch item.accessory {
        case .toggle(let isOn):
            toggle.isHidden = false
            switchView?.onTintColor = theme.accent
            if switchView?.isOn != isOn {
                switchView?.setOn(isOn, animated: switchView?.window != nil)
            }
            switchView?.isEnabled = item.isEnabled
        case .check(let isOn):
            mark.isHidden = !isOn
            mark.image = Self.symbol("checkmark", size: 16, color: theme.accent)
        case .chevron:
            mark.isHidden = false
            mark.image = Self.symbol("chevron.right", size: 13, color: theme.secondary.withAlphaComponent(0.6))
        case .none:
            break
        }
    }

    override func layout() {
        super.layout()
        guard let item else {
            return
        }

        card.frame = bounds.insetBy(dx: 16, dy: 0)
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.layer.maskedCorners = Self.corners(item.position)
        let size = card.bounds.size
        let origin = card.frame.origin
        iconBackground.frame = CGRect(x: origin.x + 14, y: origin.y + (size.height - 30) / 2, width: 30, height: 30)
        iconBackground.layer.cornerRadius = 8
        iconBackground.layer.cornerCurve = .continuous
        icon.frame = iconBackground.frame
        mark.frame = CGRect(x: card.frame.maxX - 34, y: 0, width: 22, height: bounds.height)
        let switchSize = toggle.view.sizeThatFits(.zero)
        toggle.frame = CGRect(
            x: card.frame.maxX - 14 - switchSize.width,
            y: (bounds.height - switchSize.height) / 2,
            width: switchSize.width,
            height: switchSize.height
        )
        layoutTexts(item)
        let line = 1 / max(view.traitCollection.displayScale, 1)
        let textX = origin.x + item.textX
        separator.frame = CGRect(x: textX, y: bounds.height - line, width: card.frame.maxX - textX, height: line)
    }

    private func layoutTexts(_ item: SettingsOptionItem) {
        let textX = card.frame.minX + item.textX
        let detailSize = detail.layoutThatFits(ASSizeRange(min: .zero, max: CGSize(width: 110, height: 40))).size
        let detailRight = card.frame.maxX - (item.accessory == .chevron ? 36 : 16)
        detail.frame = CGRect(
            x: detailRight - detailSize.width,
            y: (bounds.height - detailSize.height) / 2,
            width: detailSize.width,
            height: detailSize.height
        )
        let width = max(1, card.frame.maxX - item.trailing - textX)
        let range = ASSizeRange(min: .zero, max: CGSize(width: width, height: .greatestFiniteMagnitude))
        let titleSize = title.layoutThatFits(range).size
        let hasSubtitle = !(item.subtitle ?? "").isEmpty
        subtitle.isHidden = !hasSubtitle
        let subtitleSize = hasSubtitle ? subtitle.layoutThatFits(range).size : .zero
        let total = titleSize.height + (subtitleSize.height > 0 ? subtitleSize.height + 4 : 0)
        let top = (bounds.height - total) / 2
        title.frame = CGRect(x: textX, y: top, width: width, height: titleSize.height)
        subtitle.frame = CGRect(x: textX, y: title.frame.maxY + 4, width: width, height: subtitleSize.height)
    }

    private static func symbol(_ name: String, size: CGFloat, color: UIColor) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold))?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }

    static func corners(_ position: CardPosition) -> CACornerMask {
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

extension Array where Element == SettingsOptionItem {
    func positioned() -> [SettingsOptionItem] {
        enumerated().map { index, item in
            var item = item
            item.position = switch (index == 0, index == count - 1) {
            case (true, true):
                .single
            case (true, false):
                .first
            case (false, true):
                .last
            case (false, false):
                .middle
            }

            return item
        }
    }
}

extension ListTheme {
    static func settings(_ theme: AppTheme) -> ListTheme {
        ListTheme(
            background: theme.colors.background,
            rowBackground: theme.colors.surface,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.subheadline
        )
    }
}
