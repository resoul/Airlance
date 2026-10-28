@preconcurrency import AsyncDisplayKit
import UIKit

public enum ListRowElement: @unchecked Sendable {
    case text(NSAttributedString, lines: UInt, frame: CGRect)
    case image(UIImage, frame: CGRect)
    case box(UIColor, cornerRadius: CGFloat, frame: CGRect)
}

public struct ListRowContent: @unchecked Sendable {
    public var size: CGSize
    public var elements: [ListRowElement]

    public init(size: CGSize = .zero, elements: [ListRowElement] = []) {
        self.size = size
        self.elements = elements
    }

    public static func measure(_ text: NSAttributedString, width: CGFloat, lines: UInt) -> CGSize {
        let node = ASTextNode()
        node.maximumNumberOfLines = lines
        node.truncationMode = .byTruncatingTail
        node.attributedText = text
        let range = ASSizeRange(min: .zero, max: CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
        let size = node.layoutThatFits(range).size

        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}

@MainActor
public final class ListRowCanvas: ASDisplayNode {
    private var texts: [ASTextNode] = []
    private var images: [ASImageNode] = []
    private var boxes: [ASDisplayNode] = []

    override public init() {
        super.init()
        isLayerBacked = true
    }

    public func apply(_ content: ListRowContent?) {
        var used = (texts: 0, images: 0, boxes: 0)
        for element in content?.elements ?? [] {
            switch element {
            case .text(let text, let lines, let frame):
                let node = textNode(at: used.texts)
                node.maximumNumberOfLines = lines
                node.attributedText = text
                node.frame = frame
                used.texts += 1
            case .image(let image, let frame):
                let node = imageNode(at: used.images)
                node.image = image
                node.frame = frame
                used.images += 1
            case .box(let color, let cornerRadius, let frame):
                let node = boxNode(at: used.boxes)
                node.backgroundColor = color
                node.cornerRadius = cornerRadius
                node.frame = frame
                used.boxes += 1
            }
        }
        hide(texts, from: used.texts)
        hide(images, from: used.images)
        hide(boxes, from: used.boxes)
    }

    private func textNode(at index: Int) -> ASTextNode {
        if index < texts.count {
            texts[index].isHidden = false

            return texts[index]
        }

        let node = ASTextNode()
        node.isLayerBacked = true
        node.truncationMode = .byTruncatingTail
        texts.append(node)
        addSubnode(node)

        return node
    }

    private func imageNode(at index: Int) -> ASImageNode {
        if index < images.count {
            images[index].isHidden = false

            return images[index]
        }

        let node = ASImageNode()
        node.isLayerBacked = true
        node.contentMode = .center
        images.append(node)
        addSubnode(node)

        return node
    }

    private func boxNode(at index: Int) -> ASDisplayNode {
        if index < boxes.count {
            boxes[index].isHidden = false

            return boxes[index]
        }

        let node = ASDisplayNode()
        node.isLayerBacked = true
        boxes.append(node)
        insertSubnode(node, at: 0)

        return node
    }

    private func hide(_ nodes: [ASDisplayNode], from index: Int) {
        for node in nodes.dropFirst(index) {
            node.isHidden = true
        }
    }
}
