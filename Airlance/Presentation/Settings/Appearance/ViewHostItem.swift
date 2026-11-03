@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct ViewHostItem: ListItem {
    let id: String
    let height: CGFloat
    let content: UIView
    var inset: CGFloat = 16
    var revision = 0

    var version: Int {
        var hasher = Hasher()
        hasher.combine(height)
        hasher.combine(inset)
        hasher.combine(revision)
        hasher.combine(ObjectIdentifier(content))

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        height
    }

    func makeNode() -> ListItemNode {
        ViewHostNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? ViewHostNode)?.host(content, inset: inset, background: theme.background)
    }
}

final class ViewHostNode: ListItemNode {
    private weak var content: UIView?
    private var inset: CGFloat = 16

    func host(_ content: UIView, inset: CGFloat, background: UIColor) {
        backgroundColor = background
        self.inset = inset
        if self.content !== content {
            self.content?.removeFromSuperview()
            self.content = content
            view.addSubview(content)
        }
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        content?.frame = bounds.insetBy(dx: inset, dy: 0)
    }
}
