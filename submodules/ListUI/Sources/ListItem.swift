import CoreGraphics

@MainActor
public protocol ListItem {
    var id: String { get }
    var version: Int { get }
    var reuseIdentifier: String { get }
    var isMovable: Bool { get }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat
    func makeNode() -> ListItemNode
    func update(node: ListItemNode, theme: ListTheme)
    func selected()
    func tapped(node: ListItemNode, at point: CGPoint)
    func longPressed(node: ListItemNode, at point: CGPoint)
    func swipeActions() -> ListSwipeActions?
}

extension ListItem {
    public var version: Int {
        0
    }

    public var reuseIdentifier: String {
        String(reflecting: Self.self)
    }

    public var isMovable: Bool {
        false
    }

    public func selected() {
    }

    public func tapped(node: ListItemNode, at point: CGPoint) {
        selected()
    }

    public func longPressed(node: ListItemNode, at point: CGPoint) {
    }

    public func swipeActions() -> ListSwipeActions? {
        nil
    }
}
