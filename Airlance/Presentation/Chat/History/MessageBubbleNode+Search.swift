@preconcurrency import AsyncDisplayKit
import UIKit

struct SearchHighlight: Hashable, Sendable {
    let query: String
    let isCurrent: Bool
}

extension MessageBubbleNode {
    func applySearch(_ highlight: SearchHighlight?, tint: UIColor) {
        searchLayer.sublayers?.forEach { layer in
            layer.removeFromSuperlayer()
        }
        guard let highlight, let layout = textLayout, let text = layout.node.attributedText?.string else {
            searchLayer.removeFromSuperlayer()

            return
        }

        if searchLayer.superlayer == nil {
            layer.addSublayer(searchLayer)
        }
        searchLayer.frame = bounds
        let node = layout.node
        let origin = CGPoint(x: node.frame.minX + layout.origin.x, y: node.frame.minY + layout.origin.y)
        let alpha: CGFloat = highlight.isCurrent ? 0.45 : 0.2
        let color = tint.withAlphaComponent(alpha).resolvedColor(with: view.traitCollection).cgColor
        for range in Self.ranges(of: highlight.query, in: text) {
            for value in node.rects(forTextRange: range) {
                let mark = CALayer()
                mark.frame = value.cgRectValue.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -1, dy: 0)
                mark.cornerRadius = 4
                mark.backgroundColor = color
                searchLayer.addSublayer(mark)
            }
        }
    }

    private static func ranges(of query: String, in text: String) -> [NSRange] {
        let string = text as NSString
        var ranges: [NSRange] = []
        var start = 0
        while start < string.length {
            let range = string.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: NSRange(location: start, length: string.length - start)
            )
            guard range.location != NSNotFound, range.length > 0 else {
                break
            }

            ranges.append(range)
            start = NSMaxRange(range)
        }

        return ranges
    }
}
