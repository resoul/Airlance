@preconcurrency import AsyncDisplayKit
import ChatHistory
import MediaLoader
import UIKit

enum VideoReactionsFooter {
    private static let side: CGFloat = 40
    private static let spacing: CGFloat = 6
    private static let inset: CGFloat = 10

    static func attach(_ reactions: [MessageVideoReaction], to body: inout BubbleBody, scale: CGFloat) {
        guard !reactions.isEmpty else {
            return
        }

        let limit = max(body.size.width, side + inset * 2) - inset
        var origin = CGPoint(x: inset, y: body.size.height + 4)
        let corners = MediaCorners(topLeft: side / 2, topRight: side / 2, bottomLeft: side / 2, bottomRight: side / 2)
        for reaction in reactions {
            if origin.x + side > limit, origin.x > inset {
                origin = CGPoint(x: inset, y: origin.y + side + spacing)
            }
            let frame = CGRect(origin: origin, size: CGSize(width: side, height: side))
            let ring = ASDisplayNode()
            ring.isLayerBacked = true
            ring.frame = frame.insetBy(dx: -2, dy: -2)
            ring.cornerRadius = ring.frame.width / 2
            ring.borderWidth = 2
            ring.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
            let poster = ASImageNode()
            poster.isLayerBacked = true
            poster.frame = frame
            body.content.addSubnode(poster)
            body.content.addSubnode(ring)
            let source = reaction.note.source
            let request = MediaImageRequest(source: source, size: frame.size, scale: scale, corners: corners)
            body.images.append(MediaTile(node: poster, request: request))
            body.actions.append(BubbleAction(frame: frame, kind: .videoReaction(reaction.id)))
            origin.x = frame.maxX + spacing
        }
        body.size.width = max(body.size.width, min(origin.x + inset, limit + inset))
        body.size.height = origin.y + side + 8
        body.content.frame.size = body.size
    }
}
