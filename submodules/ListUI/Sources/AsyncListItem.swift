import CoreGraphics

public protocol ListPreparedLayout: AnyObject, Sendable {}

@MainActor
public protocol AsyncListItem: ListItem, Sendable {
    var layoutVersion: Int { get }

    nonisolated func prepareLayout(width: CGFloat, theme: ListTheme, displayScale: CGFloat) -> any ListPreparedLayout
    func apply(_ layout: any ListPreparedLayout, to node: ListItemNode)
}

extension AsyncListItem {
    public var layoutVersion: Int {
        version
    }
}
