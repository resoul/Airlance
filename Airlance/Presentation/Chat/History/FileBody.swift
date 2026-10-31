@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct FileBody {
    static let iconSize: CGFloat = 46

    private static let rowHeight: CGFloat = 62

    let file: MessageFile
    let caption: String
    let input: MessageBubbleInput
    let scale: CGFloat
    let maxBubble: CGFloat

    func make(style: HistoryStyle) -> BubbleBody {
        let padding = MessageBubbleLayout.padding
        let message = input.message
        let outgoing = message.isOutgoing
        let width = min(maxBubble, 270)
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
        let iconFrame = CGRect(x: 9, y: top + 8, width: Self.iconSize, height: Self.iconSize)
        let details = addRow(to: content, icon: iconFrame, width: width, style: style)
        var height = max(top + Self.rowHeight, details.maxY + padding.bottom)
        let meta = MessageMeta(input, delivery: outgoing ? message.delivery : nil, style: style)
        if caption.isEmpty {
            height = max(height, details.maxY + meta.size.height + padding.bottom)
            meta.place(in: content, bottomRight: CGPoint(x: width - 11, y: height - 7))
        } else {
            height = addCaption(to: &body, top: height - 4, width: width, meta: meta, style: style)
        }
        let size = CGSize(width: ceil(width), height: ceil(height))
        content.frame = CGRect(origin: .zero, size: size)
        body.size = size
        body.fileIcon = iconFrame
        let row = CGRect(x: 0, y: top, width: width, height: Self.rowHeight)
        body.actions.append(BubbleAction(frame: row, kind: .file))

        return body
    }

    private func addRow(to content: ASDisplayNode, icon: CGRect, width: CGFloat, style: HistoryStyle) -> CGRect {
        let outgoing = input.message.isOutgoing
        content.addSubnode(Self.icon(file, frame: icon, scale: scale))
        let detailsWidth = width - icon.maxX - 10 - MessageBubbleLayout.padding.right
        let name = MessageBubbleLayout.label(
            file.name,
            font: style.nameFont,
            color: style.text(outgoing: outgoing),
            width: detailsWidth,
            lines: 2
        )
        name.truncationMode = .byTruncatingMiddle
        name.frame.origin = CGPoint(x: icon.maxX + 10, y: icon.minY + 2)
        content.addSubnode(name)
        let details = MessageBubbleLayout.label(
            Self.details(file),
            font: style.metaFont,
            color: style.meta(outgoing: outgoing),
            width: detailsWidth
        )
        details.frame.origin = CGPoint(x: name.frame.minX, y: max(name.frame.maxY + 2, icon.maxY - 16))
        content.addSubnode(details)

        return details.frame
    }

    private func addCaption(
        to body: inout BubbleBody,
        top: CGFloat,
        width: CGFloat,
        meta: MessageMeta,
        style: HistoryStyle
    ) -> CGFloat {
        let padding = MessageBubbleLayout.padding
        let text = MessageBubbleLayout.text(
            caption,
            entities: input.message.entities,
            outgoing: input.message.isOutgoing,
            metaWidth: meta.size.width,
            style: style,
            width: width - padding.left - padding.right
        )
        text.frame.origin = CGPoint(x: padding.left, y: top)
        body.content.addSubnode(text)
        body.text = text
        meta.place(in: body.content, bottomRight: CGPoint(x: width - padding.right, y: text.frame.maxY))

        return text.frame.maxY + padding.bottom
    }

    private static func details(_ file: MessageFile) -> String {
        let size = ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
        let kind = file.fileExtension.uppercased()

        return kind.isEmpty ? size : "\(size) · \(kind)"
    }

    private static func icon(_ file: MessageFile, frame: CGRect, scale: CGFloat) -> ASImageNode {
        let node = ASImageNode()
        node.isLayerBacked = true
        node.displaysAsynchronously = false
        node.frame = frame
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        node.image = UIGraphicsImageRenderer(size: frame.size, format: format).image { _ in
            let rect = CGRect(origin: .zero, size: frame.size)
            color(for: file.fileExtension).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
            if file.isDownloaded {
                drawLabel(file.fileExtension.uppercased(), in: rect)
            } else {
                let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
                let arrow = UIImage(systemName: "arrow.down", withConfiguration: configuration)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
                arrow?.draw(at: CGPoint(
                    x: rect.midX - (arrow?.size.width ?? 0) / 2,
                    y: rect.midY - (arrow?.size.height ?? 0) / 2
                ))
            }
        }

        return node
    }

    private static func drawLabel(_ text: String, in rect: CGRect) {
        let label = String(text.prefix(4))
        let font = UIFont.systemFont(ofSize: label.count > 3 ? 11 : 13, weight: .heavy)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let size = (label as NSString).size(withAttributes: attributes)
        (label as NSString).draw(
            at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    private static func color(for fileExtension: String) -> UIColor {
        switch fileExtension {
        case "pdf":
            UIColor(red: 0.91, green: 0.30, blue: 0.27, alpha: 1)
        case "doc", "docx", "pages":
            UIColor(red: 0.23, green: 0.48, blue: 0.93, alpha: 1)
        case "xls", "xlsx", "csv", "numbers":
            UIColor(red: 0.20, green: 0.66, blue: 0.40, alpha: 1)
        case "zip", "rar", "7z":
            UIColor(red: 0.95, green: 0.58, blue: 0.18, alpha: 1)
        default:
            UIColor(red: 0.52, green: 0.55, blue: 0.62, alpha: 1)
        }
    }
}
