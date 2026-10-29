@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

final class ChatRowNode: ListItemNode {
    private let avatar = AvatarNode()
    private let onlineDot = ASDisplayNode()
    private let separator = ASDisplayNode()
    private let content = ListRowCanvas()

    override func didLoad() {
        super.didLoad()
        avatar.isOnScreen = isOnScreen
        onlineDot.isLayerBacked = true
        separator.isLayerBacked = true
        addSubnode(avatar)
        addSubnode(onlineDot)
        addSubnode(separator)
        addSubnode(content)
    }

    func update(avatar descriptor: AvatarDescriptor, storyRing: AvatarStoryRing?, isOnline: Bool, theme: ListTheme) {
        backgroundColor = theme.rowBackground
        avatar.apply(descriptor)
        avatar.setStoryRing(storyRing)
        onlineDot.isHidden = !isOnline
        onlineDot.backgroundColor = .systemGreen
        onlineDot.borderColor = theme.rowBackground.cgColor
        separator.backgroundColor = theme.separator
        setNeedsLayout()
    }

    func apply(_ layout: ChatRowLayout) {
        content.frame = CGRect(origin: .zero, size: layout.content.size)
        content.apply(layout.content)
    }

    override func visibilityChanged() {
        avatar.isOnScreen = isOnScreen
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.prepareForReuse()
        content.apply(nil)
    }

    override func layout() {
        super.layout()
        let size = ChatRowLayout.avatarSize
        avatar.frame = CGRect(x: ChatRowLayout.avatarX, y: (bounds.height - size) / 2, width: size, height: size)

        let dot: CGFloat = 16
        let origin = CGPoint(x: avatar.frame.maxX - dot + 1, y: avatar.frame.maxY - dot + 1)
        onlineDot.frame = CGRect(origin: origin, size: CGSize(width: dot, height: dot))
        onlineDot.cornerRadius = dot / 2
        onlineDot.borderWidth = 2.5

        let line = 1 / max(view.traitCollection.displayScale, 1)
        let textX = ChatRowLayout.textX
        separator.frame = CGRect(x: textX, y: bounds.height - line, width: bounds.width - textX, height: line)
    }
}
