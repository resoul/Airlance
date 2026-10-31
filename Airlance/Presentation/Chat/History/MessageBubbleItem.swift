import ListUI
import UIKit

struct MessageBubbleItem: ListItem {
    let layout: MessageBubbleLayout
    let color: UIColor
    let messageID: String
    var onLongPress: (@MainActor (MessageBubbleNode) -> Void)?
    var onLinkLongPress: (@MainActor (MessageBubbleNode, URL, CGPoint) -> Void)?
    var onPhotoTap: (@MainActor (MessageBubbleNode, Int) -> Void)?
    var onAction: (@MainActor (BubbleAction.Kind) -> Void)?
    var onBubbleTap: (@MainActor () -> Void)?
    var selection: BubbleSelection?
    var selectionTint: UIColor = .systemBlue
    var search: SearchHighlight?
    var onToggleSelection: (@MainActor () -> Void)?
    var spoilersRevealed = false
    var spoilerInk: UIColor = .gray
    var onRevealSpoiler: (@MainActor () -> Void)?

    var id: String {
        messageID
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(layout.key)
        hasher.combine(selection)
        hasher.combine(search)
        hasher.combine(spoilersRevealed)

        return hasher.finalize()
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

        guard selection == nil else {
            onToggleSelection?()

            return
        }

        guard !node.revealSpoiler(at: point) else {
            return
        }

        if let index = node.tileIndex(at: point) {
            onPhotoTap?(node, index)
        } else if let action = node.action(at: point) {
            onAction?(action)
        } else if node.bubbleFrame?.contains(point) == true {
            onBubbleTap?()
        }
    }

    func longPressed(node: ListItemNode, at point: CGPoint) {
        guard selection == nil, let node = node as? MessageBubbleNode else {
            return
        }

        if let onLinkLongPress, let url = node.linkURL(at: point), url.scheme != MessageBubbleLayout.mentionScheme {
            onLinkLongPress(node, url, point)
        } else {
            onLongPress?(node)
        }
    }

    func makeNode() -> ListItemNode {
        MessageBubbleNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        guard let node = node as? MessageBubbleNode else {
            return
        }

        let animated = node.messageID == messageID && node.selectionState != selection
        node.apply(layout, color: color)
        node.applySelection(selection, tint: selectionTint, animated: animated)
        node.applySearch(search, tint: selectionTint)
        node.applySpoilers(layout.spoilers, revealed: spoilersRevealed, ink: spoilerInk, onRevealed: onRevealSpoiler)
    }
}
