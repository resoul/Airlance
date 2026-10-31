@preconcurrency import AsyncDisplayKit
import AvatarUI
import ChatHistory
import UIKit

struct ReactionChip: Sendable, Hashable {
    let emoji: String
    let count: String?
    let avatars: [MessageCommenter]
    let isChosen: Bool
}

enum ReactionsFooter {
    private static let height: CGFloat = 28
    private static let spacing: CGFloat = 6
    private static let inset: CGFloat = 12
    private static let avatarSide: CGFloat = 20
    private static let avatarStep: CGFloat = 12
    private static let emojiFont = UIFont.systemFont(ofSize: 15)

    static func preferredWidth(_ chips: [ReactionChip], style: HistoryStyle) -> CGFloat {
        guard !chips.isEmpty else {
            return 0
        }

        let widths = chips.map { chip in
            width(of: chip, style: style)
        }

        return widths.reduce(0, +) + CGFloat(chips.count - 1) * spacing + inset * 2
    }

    static func attach(
        _ chips: [ReactionChip],
        to body: inout BubbleBody,
        outgoing: Bool,
        style: HistoryStyle,
        scale: CGFloat
    ) {
        guard !chips.isEmpty else {
            return
        }

        let limit = body.size.width - inset
        var origin = CGPoint(x: inset, y: body.size.height)
        for chip in chips {
            let width = min(width(of: chip, style: style), limit - inset)
            if origin.x + width > limit, origin.x > inset {
                origin = CGPoint(x: inset, y: origin.y + height + spacing)
            }
            let frame = CGRect(origin: origin, size: CGSize(width: width, height: height))
            place(chip, in: frame, content: body.content, outgoing: outgoing, style: style, scale: scale)
            body.actions.append(BubbleAction(frame: frame, kind: .reaction(chip.emoji)))
            origin.x = frame.maxX + spacing
        }
        body.size.height = origin.y + height + 8
        body.content.frame.size = body.size
    }

    private static func width(of chip: ReactionChip, style: HistoryStyle) -> CGFloat {
        let emoji = (chip.emoji as NSString).size(withAttributes: [.font: emojiFont]).width
        let trailing: CGFloat
        if let count = chip.count {
            trailing = (count as NSString).size(withAttributes: [.font: countFont(style)]).width
        } else {
            trailing = avatarSide + CGFloat(max(0, chip.avatars.count - 1)) * avatarStep
        }

        return ceil(8 + emoji + 4 + trailing + 9)
    }

    private static func place(
        _ chip: ReactionChip,
        in frame: CGRect,
        content: ASDisplayNode,
        outgoing: Bool,
        style: HistoryStyle,
        scale: CGFloat
    ) {
        let tint = style.tint(outgoing: outgoing)
        let background = ASDisplayNode()
        background.isLayerBacked = true
        background.backgroundColor = chip.isChosen ? tint : tint.withAlphaComponent(0.15)
        background.cornerRadius = height / 2
        background.frame = frame
        content.addSubnode(background)

        let emoji = MessageBubbleLayout.label(chip.emoji, font: emojiFont, color: .black, width: 40)
        emoji.frame.origin = CGPoint(x: frame.minX + 8, y: frame.midY - emoji.frame.height / 2)
        content.addSubnode(emoji)
        let x = emoji.frame.maxX + 4
        if let count = chip.count {
            let color = chip.isChosen ? style.bubble(outgoing: outgoing) : tint
            let label = MessageBubbleLayout.label(count, font: countFont(style), color: color, width: 80)
            label.frame.origin = CGPoint(x: x, y: frame.midY - label.frame.height / 2)
            content.addSubnode(label)

            return
        }

        for (index, person) in chip.avatars.enumerated().reversed() {
            let descriptor = AvatarDescriptor(id: person.id, initials: AvatarDescriptor.initials(from: person.name))
            let avatar = ASImageNode()
            avatar.isLayerBacked = true
            avatar.displaysAsynchronously = false
            avatar.image = descriptor.placeholderImage(side: avatarSide, scale: scale)
            avatar.frame = CGRect(
                x: x + CGFloat(index) * avatarStep,
                y: frame.midY - avatarSide / 2,
                width: avatarSide,
                height: avatarSide
            )
            content.addSubnode(avatar)
        }
    }

    private static func countFont(_ style: HistoryStyle) -> UIFont {
        UIFont.systemFont(ofSize: style.metaFont.pointSize + 1, weight: .semibold)
    }
}
