import ListUI
import UIKit

struct SpacerItem: ListItem {
    let id: String
    let height: CGFloat

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        height
    }

    func makeNode() -> ListItemNode {
        ListItemNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        node.backgroundColor = theme.background
    }
}
