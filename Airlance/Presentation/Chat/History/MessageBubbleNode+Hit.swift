@preconcurrency import AsyncDisplayKit
import UIKit

extension MessageBubbleNode {
    func tileIndex(at point: CGPoint) -> Int? {
        guard let layout = layoutResult else {
            return nil
        }

        let local = CGPoint(x: point.x - layout.bubbleFrame.minX, y: point.y - layout.bubbleFrame.minY)

        return layout.tiles.firstIndex { tile in
            tile.node.frame.contains(local)
        }
    }

    func linkURL(at point: CGPoint) -> URL? {
        guard let layout = layoutResult, let text = layout.text, !text.linkAttributeNames.isEmpty else {
            return nil
        }

        let local = CGPoint(x: point.x - layout.bubbleFrame.minX, y: point.y - layout.bubbleFrame.minY)
        guard text.frame.contains(local) else {
            return nil
        }

        let inText = CGPoint(x: local.x - text.frame.minX, y: local.y - text.frame.minY)

        return text.linkAttributeValue(at: inText, attributeName: nil, range: nil) as? URL
    }

    func action(at point: CGPoint) -> BubbleAction.Kind? {
        guard let layout = layoutResult else {
            return nil
        }

        if let url = linkURL(at: point) {
            return .url(url)
        }

        let local = CGPoint(x: point.x - layout.bubbleFrame.minX, y: point.y - layout.bubbleFrame.minY)

        return layout.actions.first { action in
            action.frame.contains(local)
        }?.kind
    }
}
