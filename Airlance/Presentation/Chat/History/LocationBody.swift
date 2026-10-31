@preconcurrency import AsyncDisplayKit
import ChatHistory
import MediaLoader
import UIKit

struct LocationBody {
    private static let mapHeight: CGFloat = 150
    private static let pinSize: CGFloat = 34

    let location: MessageLocation
    let input: MessageBubbleInput
    let scale: CGFloat
    let maxBubble: CGFloat

    func make(style: HistoryStyle) -> BubbleBody {
        let message = input.message
        let outgoing = message.isOutgoing
        let width = min(maxBubble, 260)
        let inset = MediaBody.inset
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: .zero, content: content)
        let mapTop = MediaBody.addHeader(to: &body, input: input, width: width, style: style, scale: scale)
        let mapFrame = CGRect(x: inset, y: mapTop, width: width - inset * 2, height: Self.mapHeight)
        let hasText = location.title != nil
        let corners = MediaBody.corners(for: input, hasHeader: mapTop > inset, hasCaption: hasText)
        let map = Self.mapNode(frame: mapFrame, style: style)
        content.insertSubnode(map, at: 0)
        content.addSubnode(Self.pin(at: CGPoint(x: mapFrame.midX, y: mapFrame.midY), color: style.name))
        let request = MediaImageRequest(
            source: MapSnapshots.source(location, dark: style.isDark),
            size: mapFrame.size,
            scale: scale,
            corners: corners
        )
        body.images.append(MediaTile(node: map, request: request))
        let meta = MessageMeta(
            input,
            delivery: outgoing ? message.delivery : nil,
            style: style,
            onMedia: !hasText
        )
        var height = mapFrame.maxY + inset
        if hasText {
            height = addTexts(to: content, below: mapFrame, width: width, meta: meta, style: style)
        } else {
            meta.place(in: content, bottomRight: CGPoint(x: mapFrame.maxX - 8, y: mapFrame.maxY - 6))
        }
        let size = CGSize(width: ceil(width), height: ceil(height))
        content.frame = CGRect(origin: .zero, size: size)
        body.size = size
        if let url = MapSnapshots.mapsURL(location) {
            body.actions.append(BubbleAction(frame: CGRect(origin: .zero, size: size), kind: .url(url)))
        }

        return body
    }

    private func addTexts(
        to content: ASDisplayNode,
        below map: CGRect,
        width: CGFloat,
        meta: MessageMeta,
        style: HistoryStyle
    ) -> CGFloat {
        let padding = MessageBubbleLayout.padding
        let outgoing = input.message.isOutgoing
        let textWidth = width - padding.left - padding.right
        let title = MessageBubbleLayout.label(
            location.title ?? "",
            font: style.nameFont,
            color: style.text(outgoing: outgoing),
            width: textWidth
        )
        title.frame.origin = CGPoint(x: padding.left, y: map.maxY + 6)
        content.addSubnode(title)
        var bottom = title.frame.maxY
        if let address = location.address {
            let line = MessageBubbleLayout.label(
                address,
                font: style.quoteFont,
                color: style.meta(outgoing: outgoing),
                width: textWidth - meta.size.width - 8,
                lines: 2
            )
            line.frame.origin = CGPoint(x: padding.left, y: bottom + 1)
            content.addSubnode(line)
            bottom = line.frame.maxY
        }
        bottom = max(bottom, title.frame.maxY + meta.size.height + 2)
        meta.place(in: content, bottomRight: CGPoint(x: width - padding.right, y: bottom))

        return bottom + padding.bottom
    }

    private static func mapNode(frame: CGRect, style: HistoryStyle) -> ASImageNode {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.contentMode = .scaleToFill
        node.backgroundColor = style.mediaPlaceholder
        node.cornerRadius = 4
        node.frame = frame

        return node
    }

    private static func pin(at point: CGPoint, color: UIColor) -> ASImageNode {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        let configuration = UIImage.SymbolConfiguration(pointSize: pinSize, weight: .regular)
            .applying(UIImage.SymbolConfiguration(paletteColors: [.white, color]))
        node.image = UIImage(systemName: "mappin.circle.fill", withConfiguration: configuration)
        let size = node.image?.size ?? CGSize(width: pinSize, height: pinSize)
        node.frame = CGRect(origin: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), size: size)
        node.shadowColor = UIColor.black.cgColor
        node.shadowOpacity = 0.25
        node.shadowRadius = 3
        node.shadowOffset = CGSize(width: 0, height: 1)

        return node
    }
}
