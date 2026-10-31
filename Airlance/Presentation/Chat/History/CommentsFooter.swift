@preconcurrency import AsyncDisplayKit
import AvatarUI
import ChatHistory
import UIKit

enum CommentsFooter {
    static let minWidth: CGFloat = 200

    private static let height: CGFloat = 40
    private static let avatarSide: CGFloat = 22
    private static let avatarStep: CGFloat = 14

    static func attach(
        _ text: String,
        parts: ChannelPostParts,
        to body: inout BubbleBody,
        style: HistoryStyle,
        scale: CGFloat
    ) {
        let top = body.size.height
        let width = body.size.width
        let tint = style.tint(outgoing: false)
        let line = ASDisplayNode()
        line.isLayerBacked = true
        line.backgroundColor = style.meta(outgoing: false).withAlphaComponent(0.3)
        line.frame = CGRect(x: 0, y: top, width: width, height: 1 / scale)
        body.content.addSubnode(line)

        var x: CGFloat = 12
        let commenters = Array(parts.commenters.prefix(3))
        if commenters.isEmpty {
            let icon = symbol("bubble.left.and.bubble.right", color: tint, font: style.textFont)
            icon.frame.origin = CGPoint(x: x, y: top + (height - icon.frame.height) / 2)
            body.content.addSubnode(icon)
            x = icon.frame.maxX + 8
        } else {
            for (index, commenter) in commenters.enumerated().reversed() {
                let avatar = avatarNode(commenter, scale: scale)
                let avatarX = x + CGFloat(index) * avatarStep
                avatar.frame.origin = CGPoint(x: avatarX, y: top + (height - avatarSide) / 2)
                body.content.addSubnode(avatar)
            }
            x += avatarSide + CGFloat(commenters.count - 1) * avatarStep + 8
        }

        let chevron = symbol("chevron.right", color: tint, font: style.metaFont)
        let chevronY = top + (height - chevron.frame.height) / 2
        chevron.frame.origin = CGPoint(x: width - 12 - chevron.frame.width, y: chevronY)
        body.content.addSubnode(chevron)
        let labelWidth = chevron.frame.minX - 6 - x
        let label = MessageBubbleLayout.label(text, font: style.nameFont, color: tint, width: labelWidth)
        label.frame.origin = CGPoint(x: x, y: top + (height - label.frame.height) / 2)
        body.content.addSubnode(label)

        body.actions.append(BubbleAction(frame: CGRect(x: 0, y: top, width: width, height: height), kind: .comments))
        body.size.height += height
        body.content.frame.size = body.size
    }

    private static func avatarNode(_ commenter: MessageCommenter, scale: CGFloat) -> ASImageNode {
        let descriptor = AvatarDescriptor(id: commenter.id, initials: AvatarDescriptor.initials(from: commenter.name))
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.image = descriptor.placeholderImage(side: avatarSide, scale: scale)
        node.frame = CGRect(x: 0, y: 0, width: avatarSide, height: avatarSide)

        return node
    }

    private static func symbol(_ name: String, color: UIColor, font: UIFont) -> ASImageNode {
        let configuration = UIImage.SymbolConfiguration(font: font)
        let image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.image = image
        node.frame = CGRect(origin: .zero, size: image?.size ?? .zero)

        return node
    }
}
