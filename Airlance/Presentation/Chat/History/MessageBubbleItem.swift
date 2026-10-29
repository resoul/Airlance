import ListUI
import UIKit

struct MessageBubbleItem: ListItem {
    let layout: MessageBubbleLayout
    let color: UIColor
    let messageID: String
    var onLongPress: (@MainActor (MessageBubbleNode) -> Void)?
    var onPhotoTap: (@MainActor (MessageBubbleNode, Int) -> Void)?
    var onAction: (@MainActor (BubbleAction.Kind) -> Void)?

    var id: String {
        messageID
    }

    var version: Int {
        layout.key
    }

    var reuseIdentifier: String {
        "message"
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        layout.height
    }

    func tapped(node: ListItemNode, at point: CGPoint) {
        guard let node = node as? MessageBubbleNode else {
            return
        }

        if let index = node.tileIndex(at: point) {
            onPhotoTap?(node, index)
        } else if let action = node.action(at: point) {
            onAction?(action)
        }
    }

    func longPressed(node: ListItemNode) {
        if let node = node as? MessageBubbleNode {
            onLongPress?(node)
        }
    }

    func makeNode() -> ListItemNode {
        MessageBubbleNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? MessageBubbleNode)?.apply(layout, color: color)
    }
}
