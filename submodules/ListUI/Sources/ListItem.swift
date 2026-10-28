import CoreGraphics

@MainActor
public protocol ListItem {
    var id: String { get }
    var version: Int { get }
    var reuseIdentifier: String { get }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat
    func makeNode() -> ListItemNode
    func update(node: ListItemNode, theme: ListTheme)
    func selected()
    func swipeActions() -> ListSwipeActions?
}

extension ListItem {
    public var version: Int {
        0
    }

    public var reuseIdentifier: String {
        String(reflecting: Self.self)
    }

    public func selected() {
    }

    public func swipeActions() -> ListSwipeActions? {
        nil
    }
}
