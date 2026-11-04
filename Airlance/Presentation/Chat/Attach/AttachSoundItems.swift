@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct AttachFilesItem: ListItem {
    let title: String
    let onSelect: @MainActor () -> Void

    var id: String {
        "files"
    }

    var version: Int {
        title.hashValue
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        52
    }

    func makeNode() -> ListItemNode {
        AttachFilesNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? AttachFilesNode)?.update(title: title, theme: theme)
    }

    func selected() {
        onSelect()
    }
}

final class AttachFilesNode: ListItemNode {
    private let icon = ASImageNode()
    private let title = ASTextNode()

    override func didLoad() {
        super.didLoad()
        for node in [icon, title] {
            node.isLayerBacked = true
            addSubnode(node)
        }
        icon.contentMode = .center
    }

    func update(title value: String, theme: ListTheme) {
        backgroundColor = theme.background
        let configuration = UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
        icon.image = UIImage(systemName: "icloud", withConfiguration: configuration)?
            .withTintColor(theme.accent, renderingMode: .alwaysOriginal)
        title.attributedText = NSAttributedString(
            string: value,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.accent]
        )
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        icon.frame = CGRect(x: 16, y: 0, width: 40, height: bounds.height)
        let width = max(1, bounds.width - 84)
        let size = title.layoutThatFits(ASSizeRange(min: .zero, max: CGSize(width: width, height: 30))).size
        title.frame = CGRect(x: 68, y: (bounds.height - size.height) / 2, width: width, height: size.height)
    }
}

struct AttachSectionItem: ListItem {
    let title: String

    var id: String {
        "section"
    }

    var version: Int {
        title.hashValue
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        40
    }

    func makeNode() -> ListItemNode {
        AttachSectionNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? AttachSectionNode)?.update(title: title, theme: theme)
    }
}

final class AttachSectionNode: ListItemNode {
    private let title = ASTextNode()

    override func didLoad() {
        super.didLoad()
        title.isLayerBacked = true
        addSubnode(title)
    }

    func update(title value: String, theme: ListTheme) {
        backgroundColor = theme.background
        title.attributedText = NSAttributedString(
            string: value,
            attributes: [.font: theme.subtitleFont, .foregroundColor: theme.secondary]
        )
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let width = max(1, bounds.width - 40)
        let size = title.layoutThatFits(ASSizeRange(min: .zero, max: CGSize(width: width, height: 30))).size
        title.frame = CGRect(x: 20, y: bounds.height - size.height - 6, width: width, height: size.height)
    }
}

struct AttachSoundItem: ListItem {
    static let playArea: CGFloat = 68

    let id: String
    let title: String
    let detail: String
    let artwork: UIImage?
    let isPlaying: Bool
    let showsSeparator: Bool
    let onPlay: @MainActor () -> Void
    let onSend: @MainActor () -> Void

    var version: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(detail)
        hasher.combine(artwork)
        hasher.combine(isPlaying)
        hasher.combine(showsSeparator)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        62
    }

    func makeNode() -> ListItemNode {
        AttachSoundNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? AttachSoundNode)?.update(self, theme: theme)
    }

    func tapped(node: ListItemNode, at point: CGPoint) {
        if point.x < Self.playArea {
            onPlay()
        } else {
            onSend()
        }
    }
}

final class AttachSoundNode: ListItemNode {
    private let cover = ASImageNode()
    private let glyph = ASImageNode()
    private let title = ASTextNode()
    private let detail = ASTextNode()
    private let separator = ASDisplayNode()

    override func didLoad() {
        super.didLoad()
        for node in [cover, glyph, title, detail, separator] {
            node.isLayerBacked = true
            addSubnode(node)
        }
        cover.contentMode = .scaleAspectFill
        cover.clipsToBounds = true
        glyph.contentMode = .center
        title.maximumNumberOfLines = 1
        detail.maximumNumberOfLines = 1
    }

    func update(_ item: AttachSoundItem, theme: ListTheme) {
        backgroundColor = theme.background
        cover.image = item.artwork
        cover.backgroundColor = theme.accent
        let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        let symbol = item.isPlaying ? "pause.fill" : "play.fill"
        glyph.image = UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        title.attributedText = NSAttributedString(
            string: item.title,
            attributes: [.font: theme.titleFont, .foregroundColor: theme.primary]
        )
        detail.attributedText = NSAttributedString(
            string: item.detail,
            attributes: [.font: theme.subtitleFont, .foregroundColor: theme.secondary]
        )
        separator.backgroundColor = theme.separator
        separator.isHidden = !item.showsSeparator
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        cover.frame = CGRect(x: 16, y: (height - 42) / 2, width: 42, height: 42)
        cover.cornerRadius = 21
        glyph.frame = cover.frame
        let textX = AttachSoundItem.playArea
        let width = max(1, bounds.width - textX - 16)
        let range = ASSizeRange(min: .zero, max: CGSize(width: width, height: 30))
        let titleSize = title.layoutThatFits(range).size
        let detailSize = detail.layoutThatFits(range).size
        let top = (height - titleSize.height - detailSize.height - 2) / 2
        title.frame = CGRect(x: textX, y: top, width: width, height: titleSize.height)
        detail.frame = CGRect(x: textX, y: title.frame.maxY + 2, width: width, height: detailSize.height)
        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: textX, y: height - line, width: bounds.width - textX, height: line)
    }
}
