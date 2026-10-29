@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct MediaBody {
    static let inset: CGFloat = 2
    private static let innerRadius: CGFloat = 4
    private static let bigRadius: CGFloat = 17
    private static let smallRadius: CGFloat = 6

    let photos: [MessagePhoto]
    let caption: String
    let input: MessageBubbleInput
    let scale: CGFloat
    let maxBubble: CGFloat

    func make(style: HistoryStyle) -> BubbleBody {
        let message = input.message
        let mosaic = PhotoMosaic(photos, maxWidth: maxBubble - Self.inset * 2)
        let width = mosaic.size.width + Self.inset * 2
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: .zero, content: content)
        let mediaTop = addHeader(to: &body, width: width, style: style)
        let mediaFrame = CGRect(origin: CGPoint(x: Self.inset, y: mediaTop), size: mosaic.size)
        let hasCaption = !caption.isEmpty
        let meta = MessageMeta(
            time: input.timeText,
            delivery: message.isOutgoing ? message.delivery : nil,
            style: style,
            onMedia: !hasCaption
        )
        var height = mediaFrame.maxY + Self.inset
        if hasCaption {
            height = addCaption(to: &body, below: mediaFrame, width: width, meta: meta, style: style)
        }

        let corners = Self.corners(for: input, hasHeader: mediaTop > Self.inset, hasCaption: hasCaption)
        let tiles = zip(photos, mosaic.frames).map { photo, frame in
            let frame = frame.offsetBy(dx: mediaFrame.minX, dy: mediaFrame.minY)

            return tile(photo, frame: frame, mosaic: mediaFrame, corners: corners, style: style)
        }
        for tile in tiles {
            content.insertSubnode(tile.node, at: 0)
            if let overlay = tile.overlay {
                content.addSubnode(overlay)
            }
        }
        if !hasCaption {
            meta.place(in: content, bottomRight: CGPoint(x: mediaFrame.maxX - 8, y: mediaFrame.maxY - 6))
        }

        let size = CGSize(width: ceil(width), height: ceil(height))
        content.frame = CGRect(origin: .zero, size: size)
        body.size = size
        body.tiles = tiles

        return body
    }

    private func addHeader(to body: inout BubbleBody, width: CGFloat, style: HistoryStyle) -> CGFloat {
        Self.addHeader(to: &body, input: input, width: width, style: style, scale: scale)
    }

    static func addHeader(
        to body: inout BubbleBody,
        input: MessageBubbleInput,
        width: CGFloat,
        style: HistoryStyle,
        scale: CGFloat
    ) -> CGFloat {
        let padding = MessageBubbleLayout.padding
        let textWidth = width - padding.left - padding.right
        let header = BubbleHeader(input, style: style, maxWidth: textWidth, scale: scale)
        guard !header.isEmpty else {
            return inset
        }

        let origin = CGPoint(x: padding.left, y: padding.top)
        body.add(header.place(in: body.content, at: origin, width: textWidth))

        return padding.top + header.size.height + 5
    }

    private func addCaption(
        to body: inout BubbleBody,
        below media: CGRect,
        width: CGFloat,
        meta: MessageMeta,
        style: HistoryStyle
    ) -> CGFloat {
        let padding = MessageBubbleLayout.padding
        let text = MessageBubbleLayout.text(
            caption,
            outgoing: input.message.isOutgoing,
            metaWidth: meta.size.width,
            style: style,
            width: width - padding.left - padding.right
        )
        text.frame.origin = CGPoint(x: padding.left, y: media.maxY + 6)
        body.content.addSubnode(text)
        if !text.linkAttributeNames.isEmpty {
            body.linkText = text
        }
        meta.place(in: body.content, bottomRight: CGPoint(x: width - padding.right, y: text.frame.maxY))

        return text.frame.maxY + padding.bottom
    }

    private func tile(
        _ photo: MessagePhoto,
        frame: CGRect,
        mosaic: CGRect,
        corners outer: MediaCorners,
        style: HistoryStyle
    ) -> MediaTile {
        let touches = (
            top: abs(frame.minY - mosaic.minY) < 0.5,
            bottom: abs(frame.maxY - mosaic.maxY) < 0.5,
            left: abs(frame.minX - mosaic.minX) < 0.5,
            right: abs(frame.maxX - mosaic.maxX) < 0.5
        )
        let corners = MediaCorners(
            topLeft: touches.top && touches.left ? outer.topLeft : 0,
            topRight: touches.top && touches.right ? outer.topRight : 0,
            bottomLeft: touches.bottom && touches.left ? outer.bottomLeft : 0,
            bottomRight: touches.bottom && touches.right ? outer.bottomRight : 0
        )
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.contentMode = .scaleToFill
        node.backgroundColor = style.mediaPlaceholder
        node.cornerRadius = Self.innerRadius
        node.frame = frame
        let request = MediaImageRequest(source: photo.source, size: frame.size, scale: scale, corners: corners)
        let overlay = photo.video.map { video in
            VideoBadge.make(duration: video.duration, frame: frame, style: style)
        }

        return MediaTile(node: node, request: request, overlay: overlay)
    }

    static func corners(for input: MessageBubbleInput, hasHeader: Bool, hasCaption: Bool) -> MediaCorners {
        let grouping = input.grouping
        let near = (
            top: grouping.joinedTop ? Self.smallRadius : Self.bigRadius,
            bottom: grouping.joinedBottom ? Self.smallRadius : Self.innerRadius + Self.inset
        )
        let far = Self.bigRadius
        var corners = input.message.isOutgoing
            ? MediaCorners(topLeft: far, topRight: near.top, bottomLeft: far, bottomRight: near.bottom)
            : MediaCorners(topLeft: near.top, topRight: far, bottomLeft: near.bottom, bottomRight: far)
        corners = MediaCorners(
            topLeft: max(Self.innerRadius, corners.topLeft - Self.inset),
            topRight: max(Self.innerRadius, corners.topRight - Self.inset),
            bottomLeft: max(Self.innerRadius, corners.bottomLeft - Self.inset),
            bottomRight: max(Self.innerRadius, corners.bottomRight - Self.inset)
        )
        if hasHeader {
            corners.topLeft = Self.innerRadius
            corners.topRight = Self.innerRadius
        }
        if hasCaption {
            corners.bottomLeft = Self.innerRadius
            corners.bottomRight = Self.innerRadius
        }

        return corners
    }
}
