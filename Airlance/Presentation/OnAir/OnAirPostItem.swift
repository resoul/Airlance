@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

struct OnAirPostItem: AsyncListItem {
    nonisolated static let maxLines: UInt = 5

    let post: OnAirPost
    let channel: OnAirChannel
    let time: String
    let views: String
    let boosts: String
    let comments: String
    let level: OnAirLevel
    let isJoined: Bool
    let showsSeparator: Bool
    let swipe: ListSwipeActions?
    let onVisible: @MainActor (Bool) -> Void
    let onLongPress: @MainActor () -> Void
    let onSelect: @MainActor () -> Void

    var id: String {
        post.id
    }

    var layoutVersion: Int {
        var hasher = Hasher()
        hasher.combine(post)
        hasher.combine(channel.name)
        hasher.combine(time)
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
        let text = Self.textHeight(post.text, width: width - 32, font: theme.titleFont)

        return (14 + 32 + 8 + text + 10 + theme.subtitleFont.lineHeight + 14).rounded(.up)
    }

    func makeNode() -> ListItemNode {
        OnAirPostNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? OnAirPostNode)?.update(self, theme: theme)
    }

    func selected() {
        onSelect()
    }

    func longPressed(node: ListItemNode, at point: CGPoint) {
        onLongPress()
    }

    func swipeActions() -> ListSwipeActions? {
        swipe
    }

    nonisolated func prepareLayout(width: CGFloat, theme: ListTheme, displayScale: CGFloat) -> any ListPreparedLayout {
        OnAirPostLayout(item: self, width: width, theme: theme)
    }

    func apply(_ layout: any ListPreparedLayout, to node: ListItemNode) {
        guard let layout = layout as? OnAirPostLayout else {
            return
        }

        (node as? OnAirPostNode)?.apply(layout)
    }

    static func textHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )

        return min(bounds.height, font.lineHeight * CGFloat(maxLines)).rounded(.up)
    }
}

final class OnAirPostLayout: ListPreparedLayout, @unchecked Sendable {
    let header: ListRowContent
    let time: ListRowContent
    let body: ListRowContent
    let stats: ListRowContent

    init(item: OnAirPostItem, width: CGFloat, theme: ListTheme) {
        let timeText = OnAirText.string(item.time, font: theme.subtitleFont, color: theme.secondary, alignment: .right)
        time = OnAirText.stack([timeText], width: 80, alignment: .right)
        let name = OnAirName.text(
            item.channel.name,
            level: item.level,
            isJoined: item.isJoined,
            font: UIFont.systemFont(ofSize: theme.subtitleFont.pointSize, weight: .semibold),
            color: theme.primary,
            accent: theme.accent
        )
        header = OnAirText.stack([name], width: max(1, width - 56 - 96), alignment: .left)
        let text = OnAirText.string(item.post.text, font: theme.titleFont, color: theme.primary)
        body = OnAirText.stack([text], width: width - 32, alignment: .left, maxLines: [OnAirPostItem.maxLines])
        stats = OnAirText.stack([Self.stats(item, theme: theme)], width: width - 32, alignment: .left)
    }

    private static func stats(_ item: OnAirPostItem, theme: ListTheme) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = theme.subtitleFont
        let parts = [
            ("eye", item.views, theme.secondary),
            ("star.fill", item.boosts, theme.accent),
            ("bubble.right", item.comments, theme.secondary),
        ]
        for (index, part) in parts.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "    "))
            }
            let image = ListRowSymbols.image(part.0, size: font.pointSize * 0.85, color: part.2)
            result.append(NSAttributedString(attachment: OnAirName.attachment(image, font: font)))
            result.append(NSAttributedString(string: " " + part.1, attributes: [
                .font: font,
                .foregroundColor: part.2,
            ]))
        }

        return result
    }
}

final class OnAirPostNode: ListItemNode {
    private var onVisible: (@MainActor (Bool) -> Void)?
    private let avatar = AvatarNode()
    private let separator = ASDisplayNode()
    private let header = ListRowCanvas()
    private let time = ListRowCanvas()
    private let body = ListRowCanvas()
    private let stats = ListRowCanvas()

    override func didLoad() {
        super.didLoad()
        avatar.isOnScreen = isOnScreen
        separator.isLayerBacked = true
        for node in [avatar, separator, header, time, body, stats] {
            addSubnode(node)
        }
    }

    func update(_ item: OnAirPostItem, theme: ListTheme) {
        backgroundColor = theme.rowBackground
        avatar.apply(PeerAvatars.descriptor(id: item.channel.id, name: item.channel.name))
        separator.backgroundColor = theme.separator
        separator.isHidden = !item.showsSeparator
        onVisible = item.onVisible
        if isOnScreen {
            item.onVisible(true)
        }
    }

    func apply(_ layout: OnAirPostLayout) {
        let pairs = [(header, layout.header), (time, layout.time), (body, layout.body), (stats, layout.stats)]
        for (canvas, content) in pairs {
            canvas.frame.size = content.size
            canvas.apply(content)
        }
        setNeedsLayout()
    }

    override func visibilityChanged() {
        avatar.isOnScreen = isOnScreen
        onVisible?(isOnScreen)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.prepareForReuse()
        onVisible?(false)
        onVisible = nil
        for canvas in [header, time, body, stats] {
            canvas.apply(nil)
        }
    }

    override func layout() {
        super.layout()
        avatar.frame = CGRect(x: 16, y: 14, width: 32, height: 32)
        time.frame.origin = CGPoint(x: bounds.width - 96, y: avatar.frame.midY - time.frame.height / 2)
        header.frame.origin = CGPoint(x: 56, y: avatar.frame.midY - header.frame.height / 2)
        body.frame.origin = CGPoint(x: 16, y: avatar.frame.maxY + 8)
        stats.frame.origin = CGPoint(x: 16, y: body.frame.maxY + 10)
        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: 16, y: bounds.height - line, width: bounds.width - 16, height: line)
    }
}
