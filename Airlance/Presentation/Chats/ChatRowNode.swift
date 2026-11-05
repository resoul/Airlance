@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

final class ChatRowNode: ListItemNode {
    private let avatar = AvatarNode()
    private let onlineDot = ASDisplayNode()
    private let separator = ASDisplayNode()
    private let content = ListRowCanvas()
    private let thumbnails = ChatRowThumbnailsNode()
    private let typingDots = ChatRowTypingNode()
    private var isTyping = false

    override func didLoad() {
        super.didLoad()
        avatar.isOnScreen = isOnScreen
        onlineDot.isLayerBacked = true
        separator.isLayerBacked = true
        addSubnode(avatar)
        addSubnode(onlineDot)
        addSubnode(separator)
        addSubnode(content)
        addSubnode(thumbnails)
        addSubnode(typingDots)
        typingDots.isHidden = true
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

    var avatarFrame: CGRect {
        let size = ChatRowLayout.avatarSize

        return CGRect(x: ChatRowLayout.avatarX, y: (bounds.height - size) / 2, width: size, height: size)
    }

    func avatarFrame(in view: UIView) -> CGRect {
        self.view.convert(avatarFrame, to: view)
    }

    func setAvatarHidden(_ isHidden: Bool) {
        avatar.isHidden = isHidden
        onlineDot.alpha = isHidden ? 0 : 1
    }

    func apply(_ layout: ChatRowLayout) {
        content.frame = CGRect(origin: .zero, size: layout.content.size)
        content.apply(layout.content)
        thumbnails.frame = content.frame
        thumbnails.show(
            layout.thumbnails,
            frames: layout.thumbnailFrames,
            scale: max(view.traitCollection.displayScale, 1)
        )
        isTyping = layout.typingOrigin != nil
        typingDots.isHidden = !isTyping
        if let origin = layout.typingOrigin {
            typingDots.frame = CGRect(origin: origin, size: CGSize(width: ChatRowTypingNode.width, height: 4))
            typingDots.apply(color: layout.typingColor)
        }
        typingDots.setAnimating(isTyping && isOnScreen)
    }

    override func visibilityChanged() {
        avatar.isOnScreen = isOnScreen
        typingDots.setAnimating(isTyping && isOnScreen)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.prepareForReuse()
        setAvatarHidden(false)
        content.apply(nil)
        thumbnails.clear()
        isTyping = false
        typingDots.isHidden = true
        typingDots.setAnimating(false)
    }

    override func layout() {
        super.layout()
        avatar.frame = avatarFrame

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
