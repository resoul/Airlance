@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

final class ChatRowNode: ListItemNode {
    private let avatar = AvatarNode()
    private let onlineDot = ASDisplayNode()
    private let separator = ASDisplayNode()
    private var content: ASDisplayNode?

    override func didLoad() {
        super.didLoad()
        onlineDot.isLayerBacked = true
        separator.isLayerBacked = true
        addSubnode(avatar)
        addSubnode(onlineDot)
        addSubnode(separator)
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
        content?.removeFromSupernode()
        content = layout.content
        addSubnode(layout.content)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.prepareForReuse()
        content?.removeFromSupernode()
        content = nil
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
