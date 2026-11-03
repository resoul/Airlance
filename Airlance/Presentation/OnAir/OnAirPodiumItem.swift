@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

struct OnAirPodiumItem: ListItem {
    let entries: [RankedChannel]
    let values: [String]
    let onSelect: @MainActor (String) -> Void

    var id: String {
        "podium"
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(entries.map(\.channel.id))
        hasher.combine(entries.map(\.channel.name))
        hasher.combine(values)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        (OnAirPodiumNode.firstTop + 84 + 20 + theme.titleFont.lineHeight * 2 + theme.subtitleFont.lineHeight + 14)
            .rounded(.up)
    }

    func makeNode() -> ListItemNode {
        OnAirPodiumNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? OnAirPodiumNode)?.update(self, theme: theme)
    }

    func tapped(node: ListItemNode, at point: CGPoint) {
        guard let column = (node as? OnAirPodiumNode)?.column(at: point), entries.indices.contains(column) else {
            return
        }

        onSelect(entries[column].channel.id)
    }
}

final class OnAirPodiumNode: ListItemNode {
    static let firstTop: CGFloat = 16

    private static let order = [1, 0, 2]

    private let avatars = (0..<3).map { _ in
        AvatarNode()
    }
    private let rings = (0..<3).map { _ in
        ASDisplayNode()
    }
    private let badges = (0..<3).map { _ in
        ASTextNode()
    }
    private let names = (0..<3).map { _ in
        ASTextNode()
    }
    private let values = (0..<3).map { _ in
        ASTextNode()
    }
    private var count = 0

    override func didLoad() {
        super.didLoad()
        for index in 0..<3 {
            for node in [rings[index], badges[index], names[index], values[index]] {
                node.isLayerBacked = true
                addSubnode(node)
            }
            avatars[index].isOnScreen = isOnScreen
            insertSubnode(avatars[index], aboveSubnode: rings[index])
            names[index].maximumNumberOfLines = 2
            values[index].maximumNumberOfLines = 1
            badges[index].maximumNumberOfLines = 1
        }
    }

    func update(_ item: OnAirPodiumItem, theme: ListTheme) {
        backgroundColor = theme.rowBackground
        count = item.entries.count
        let center = NSMutableParagraphStyle()
        center.alignment = .center
        for index in 0..<3 {
            let isVisible = item.entries.indices.contains(index)
            for node in [avatars[index], rings[index], badges[index], names[index], values[index]] {
                node.isHidden = !isVisible
            }
            guard isVisible else {
                continue
            }

            let channel = item.entries[index].channel
            let medal = OnAirLevel.medals[index]
            avatars[index].apply(PeerAvatars.descriptor(id: channel.id, name: channel.name))
            rings[index].borderColor = medal.cgColor
            rings[index].borderWidth = index == 0 ? 3 : 2.5
            rings[index].backgroundColor = .clear
            badges[index].backgroundColor = medal
            badges[index].attributedText = NSAttributedString(string: String(index + 1), attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .heavy),
                .foregroundColor: UIColor.black,
                .paragraphStyle: center,
            ])
            let nameFont = index == 0 ? UIFont.systemFont(ofSize: theme.titleFont.pointSize, weight: .semibold)
                : theme.subtitleFont
            names[index].attributedText = NSAttributedString(string: channel.name, attributes: [
                .font: nameFont,
                .foregroundColor: theme.primary,
                .paragraphStyle: center,
            ])
            let value = item.values.indices.contains(index) ? item.values[index] : ""
            values[index].attributedText = NSAttributedString(string: value, attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: theme.subtitleFont.pointSize, weight: .semibold),
                .foregroundColor: theme.accent,
                .paragraphStyle: center,
            ])
        }
        setNeedsLayout()
    }

    func column(at point: CGPoint) -> Int? {
        let width = bounds.width / 3
        let slot = min(2, max(0, Int(point.x / max(width, 1))))
        let index = Self.order[slot]

        return index < count ? index : nil
    }

    override func visibilityChanged() {
        for avatar in avatars {
            avatar.isOnScreen = isOnScreen
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        for avatar in avatars {
            avatar.prepareForReuse()
        }
    }

    override func layout() {
        super.layout()
        let width = (bounds.width - 16) / 3
        for (slot, index) in Self.order.enumerated() {
            let size: CGFloat = index == 0 ? 84 : 64
            let top = index == 0 ? Self.firstTop : Self.firstTop + 22
            let centerX = 8 + width * (CGFloat(slot) + 0.5)
            let frame = CGRect(x: centerX - size / 2, y: top, width: size, height: size)
            avatars[index].frame = frame
            rings[index].frame = frame.insetBy(dx: -5, dy: -5)
            rings[index].cornerRadius = rings[index].frame.width / 2
            badges[index].frame = CGRect(x: centerX - 11, y: frame.maxY - 6, width: 22, height: 18)
            badges[index].cornerRadius = 9
            let range = ASSizeRange(min: .zero, max: CGSize(width: width - 8, height: 60))
            let nameHeight = names[index].layoutThatFits(range).size.height
            names[index].frame = CGRect(
                x: centerX - width / 2 + 4,
                y: frame.maxY + 18,
                width: width - 8,
                height: nameHeight
            )
            let valueHeight = values[index].layoutThatFits(range).size.height
            values[index].frame = CGRect(
                x: centerX - width / 2,
                y: names[index].frame.maxY + 2,
                width: width,
                height: valueHeight
            )
        }
    }
}
