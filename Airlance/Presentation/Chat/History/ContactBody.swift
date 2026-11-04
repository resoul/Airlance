@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct ContactBody {
    private static let avatarSize: CGFloat = 46

    let contact: MessageContact
    let input: MessageBubbleInput
    let scale: CGFloat
    let maxBubble: CGFloat

    func make(style: HistoryStyle) -> BubbleBody {
        let padding = MessageBubbleLayout.padding
        let message = input.message
        let outgoing = message.isOutgoing
        let width = min(maxBubble, 250)
        let textWidth = width - padding.left - padding.right
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: .zero, content: content)
        let header = BubbleHeader(input, style: style, maxWidth: textWidth, scale: scale)
        var top: CGFloat = 0
        if !header.isEmpty {
            body.add(header.place(in: content, at: CGPoint(x: padding.left, y: padding.top), width: textWidth))
            top = padding.top + header.size.height - 2
        }
        let side = Self.avatarSize
        let avatarFrame = CGRect(x: 9, y: top + 8, width: side, height: side)
        content.addSubnode(avatar(frame: avatarFrame, color: style.text(outgoing: outgoing)))
        let textBottom = addLabels(to: content, avatar: avatarFrame, width: width, style: style)
        let meta = MessageMeta(input, delivery: outgoing ? message.delivery : nil, style: style)
        let height = max(avatarFrame.maxY, textBottom) + meta.size.height + padding.bottom
        meta.place(in: content, bottomRight: CGPoint(x: width - 11, y: height - 7))
        let size = CGSize(width: ceil(width), height: ceil(height))
        content.frame = CGRect(origin: .zero, size: size)
        body.size = size
        if let url = Self.callURL(contact.phone) {
            body.actions.append(BubbleAction(frame: CGRect(origin: .zero, size: size), kind: .url(url)))
        }

        return body
    }

    private func addLabels(to content: ASDisplayNode, avatar: CGRect, width: CGFloat, style: HistoryStyle) -> CGFloat {
        let outgoing = input.message.isOutgoing
        let textX = avatar.maxX + 10
        let labelWidth = width - textX - MessageBubbleLayout.padding.right
        let name = MessageBubbleLayout.label(
            contact.name,
            font: style.nameFont,
            color: style.text(outgoing: outgoing),
            width: labelWidth
        )
        name.frame.origin = CGPoint(x: textX, y: avatar.minY + 3)
        content.addSubnode(name)
        let phone = MessageBubbleLayout.label(
            contact.phone,
            font: style.metaFont,
            color: style.meta(outgoing: outgoing),
            width: labelWidth
        )
        phone.frame.origin = CGPoint(x: textX, y: name.frame.maxY + 2)
        content.addSubnode(phone)

        return phone.frame.maxY
    }

    private func avatar(frame: CGRect, color: UIColor) -> ASImageNode {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.image = Self.avatarImage(contact.name, side: frame.width, scale: scale, color: color)
        node.frame = frame

        return node
    }

    private static func callURL(_ phone: String) -> URL? {
        let digits = phone.filter { character in
            character.isNumber || character == "+"
        }

        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    private static func avatarImage(_ name: String, side: CGFloat, scale: CGFloat, color: UIColor) -> UIImage {
        let initials = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)

        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            color.withAlphaComponent(0.18).setFill()
            context.cgContext.fillEllipse(in: bounds)
            let text = NSAttributedString(
                string: initials.uppercased(),
                attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: color]
            )
            let size = text.size()
            text.draw(at: CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2))
        }
    }
}
