@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct LinkCard {
    private static let leading: CGFloat = 10
    private static let trailing: CGFloat = 8
    private static let vertical: CGFloat = 6
    private static let thumbSize: CGFloat = 48

    let size: CGSize

    private let preview: LinkPreview
    private let url: URL?
    private let texts: [ASTextNode]
    private let tint: UIColor
    private let style: HistoryStyle
    private let scale: CGFloat
    private let photoSize: CGSize?

    private struct Line {
        let text: String
        let font: UIFont
        let color: UIColor
        let lines: Int
    }

    init(
        _ link: MessageLink,
        preview: LinkPreview,
        outgoing: Bool,
        style: HistoryStyle,
        maxWidth: CGFloat,
        scale: CGFloat
    ) {
        let tint = style.tint(outgoing: outgoing)
        let hasThumb = preview.photo != nil && !preview.hasLargePhoto
        let textWidth = maxWidth - Self.leading - Self.trailing - (hasThumb ? Self.thumbSize + 8 : 0)
        texts = Self.texts(preview, tint: tint, color: style.text(outgoing: outgoing), style: style, width: textWidth)
        let textHeight = texts.map(\.frame.height).reduce(0, +) + CGFloat(max(0, texts.count - 1))
        let textMaxWidth = texts.map(\.frame.width).max() ?? 0
        var height = Self.vertical * 2 + (hasThumb ? max(textHeight, Self.thumbSize) : textHeight)
        var width = min(maxWidth, textMaxWidth + Self.leading + Self.trailing + (hasThumb ? Self.thumbSize + 8 : 0))
        var photoSize: CGSize?
        if let photo = preview.photo, preview.hasLargePhoto {
            width = maxWidth
            let photoWidth = maxWidth - Self.leading - Self.trailing
            let photoHeight = min(photoWidth, max(photoWidth * 0.5, photoWidth / CGFloat(photo.aspectRatio)))
            photoSize = CGSize(width: photoWidth, height: floor(photoHeight))
            height += floor(photoHeight) + 6
        }
        self.preview = preview
        url = URL(string: link.url)
        self.tint = tint
        self.style = style
        self.scale = scale
        self.photoSize = photoSize
        size = CGSize(width: ceil(width), height: ceil(height))
    }

    func place(in content: ASDisplayNode, at origin: CGPoint, width: CGFloat) -> (MediaTile?, BubbleAction?) {
        let frame = CGRect(origin: origin, size: CGSize(width: width, height: size.height))
        content.addSubnode(BubbleHeader.quoteBackground(frame: frame, tint: tint, alpha: 0.1))
        var y = frame.minY + Self.vertical
        for text in texts {
            text.frame.origin = CGPoint(x: frame.minX + Self.leading, y: y)
            content.addSubnode(text)
            y = text.frame.maxY + 1
        }
        var tile: MediaTile?
        if let photo = preview.photo {
            let photoFrame: CGRect
            if let photoSize {
                photoFrame = CGRect(origin: CGPoint(x: frame.minX + Self.leading, y: y + 5), size: photoSize)
            } else {
                let x = frame.maxX - Self.trailing - Self.thumbSize
                photoFrame = CGRect(x: x, y: frame.minY + Self.vertical, width: Self.thumbSize, height: Self.thumbSize)
            }
            tile = image(photo, frame: photoFrame, in: content)
        }
        let action = url.map { url in
            BubbleAction(frame: frame, kind: .url(url))
        }

        return (tile, action)
    }

    private func image(_ photo: MessagePhoto, frame: CGRect, in content: ASDisplayNode) -> MediaTile {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.backgroundColor = style.mediaPlaceholder
        node.cornerRadius = 6
        node.frame = frame
        content.addSubnode(node)
        let corners = MediaCorners(topLeft: 6, topRight: 6, bottomLeft: 6, bottomRight: 6)
        let request = MediaImageRequest(source: photo.source, size: frame.size, scale: scale, corners: corners)

        return MediaTile(node: node, request: request)
    }

    private static func texts(
        _ preview: LinkPreview,
        tint: UIColor,
        color: UIColor,
        style: HistoryStyle,
        width textWidth: CGFloat
    ) -> [ASTextNode] {
        let lines = [
            Line(text: preview.site, font: style.nameFont, color: tint, lines: 1),
            Line(text: preview.title, font: style.nameFont, color: color, lines: 2),
            Line(text: preview.summary, font: style.quoteFont, color: color, lines: 3),
        ]

        return lines
            .filter { line in
                !line.text.isEmpty
            }
            .map { line in
                MessageBubbleLayout.label(
                    line.text,
                    font: line.font,
                    color: line.color,
                    width: textWidth,
                    lines: line.lines
                )
            }
    }
}
