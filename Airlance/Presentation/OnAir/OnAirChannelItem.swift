@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

struct OnAirBadge: Hashable, Sendable {
    let text: String
    let color: UIColor
}

struct OnAirChannelItem: AsyncListItem {
    let channel: OnAirChannel
    let position: Int
    let subtitle: String
    let value: OnAirBadge
    let detail: OnAirBadge
    let level: OnAirLevel
    let isJoined: Bool
    let showsSeparator: Bool
    let onSelect: @MainActor () -> Void

    var id: String {
        "channel-" + channel.id
    }

    var layoutVersion: Int {
        var hasher = Hasher()
        hasher.combine(channel.name)
        hasher.combine(position)
        hasher.combine(subtitle)
        hasher.combine(value)
        hasher.combine(detail)
        hasher.combine(level)
        hasher.combine(isJoined)

        return hasher.finalize()
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(layoutVersion)
        hasher.combine(showsSeparator)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        max(68, (theme.titleFont.lineHeight + theme.subtitleFont.lineHeight + 26).rounded(.up))
    }

    func makeNode() -> ListItemNode {
        OnAirChannelNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? OnAirChannelNode)?.update(channel: channel, showsSeparator: showsSeparator, theme: theme)
    }

    func selected() {
        onSelect()
    }

    nonisolated func prepareLayout(width: CGFloat, theme: ListTheme, displayScale: CGFloat) -> any ListPreparedLayout {
        OnAirChannelLayout(item: self, width: width, theme: theme)
    }

    func apply(_ layout: any ListPreparedLayout, to node: ListItemNode) {
        guard let layout = layout as? OnAirChannelLayout else {
            return
        }

        (node as? OnAirChannelNode)?.apply(layout)
    }
}

final class OnAirChannelLayout: ListPreparedLayout, @unchecked Sendable {
    static let rankWidth: CGFloat = 36
    static let textX: CGFloat = 108
    static let rightWidth: CGFloat = 84

    let rank: ListRowContent
    let text: ListRowContent
    let right: ListRowContent

    init(item: OnAirChannelItem, width: CGFloat, theme: ListTheme) {
        let rankFont = UIFont.monospacedDigitSystemFont(ofSize: theme.titleFont.pointSize, weight: .bold)
        let rankColor = item.position <= 3 ? theme.accent : theme.secondary
        let rankText = OnAirText.string(String(item.position), font: rankFont, color: rankColor, alignment: .center)
        rank = OnAirText.stack([rankText], width: Self.rankWidth, alignment: .center)

        let textWidth = max(1, width - Self.textX - Self.rightWidth - 20)
        let name = OnAirName.text(
            item.channel.name,
            level: item.level,
            isJoined: item.isJoined,
            font: theme.titleFont,
            color: theme.primary,
            accent: theme.accent
        )
        let subtitle = OnAirText.string(item.subtitle, font: theme.subtitleFont, color: theme.secondary)
        text = OnAirText.stack([name, subtitle], width: textWidth, alignment: .left)

        let valueFont = UIFont.monospacedDigitSystemFont(ofSize: theme.subtitleFont.pointSize, weight: .semibold)
        let detailFont = UIFont.monospacedDigitSystemFont(ofSize: theme.subtitleFont.pointSize - 1, weight: .medium)
        right = OnAirText.stack(
            [
                OnAirText.string(item.value.text, font: valueFont, color: item.value.color, alignment: .right),
                OnAirText.string(item.detail.text, font: detailFont, color: item.detail.color, alignment: .right),
            ],
            width: Self.rightWidth,
            alignment: .right
        )
    }
}

final class OnAirChannelNode: ListItemNode {
    private let avatar = AvatarNode()
    private let separator = ASDisplayNode()
    private let rank = ListRowCanvas()
    private let text = ListRowCanvas()
    private let right = ListRowCanvas()

    override func didLoad() {
        super.didLoad()
        avatar.isOnScreen = isOnScreen
        separator.isLayerBacked = true
        for node in [avatar, separator, rank, text, right] {
            addSubnode(node)
        }
    }

    func update(channel: OnAirChannel, showsSeparator: Bool, theme: ListTheme) {
        backgroundColor = theme.rowBackground
        avatar.apply(PeerAvatars.descriptor(id: channel.id, name: channel.name))
        separator.backgroundColor = theme.separator
        separator.isHidden = !showsSeparator
    }

    func apply(_ layout: OnAirChannelLayout) {
        rank.frame.size = layout.rank.size
        rank.apply(layout.rank)
        text.frame.size = layout.text.size
        text.apply(layout.text)
        right.frame.size = layout.right.size
        right.apply(layout.right)
        setNeedsLayout()
    }

    override func visibilityChanged() {
        avatar.isOnScreen = isOnScreen
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.prepareForReuse()
        rank.apply(nil)
        text.apply(nil)
        right.apply(nil)
    }

    override func layout() {
        super.layout()
        let midY = bounds.height / 2
        let textX = OnAirChannelLayout.textX
        rank.frame.origin = CGPoint(x: 12, y: midY - rank.frame.height / 2)
        avatar.frame = CGRect(x: 54, y: midY - 22, width: 44, height: 44)
        text.frame.origin = CGPoint(x: textX, y: midY - text.frame.height / 2)
        right.frame.origin = CGPoint(
            x: bounds.width - OnAirChannelLayout.rightWidth - 16,
            y: midY - right.frame.height / 2
        )
        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: textX, y: bounds.height - line, width: bounds.width - textX, height: line)
    }
}
