@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
public protocol ScrollablePane: AnyObject {
    var node: ASDisplayNode { get }
    var verticalOffset: CGFloat { get }
    var maximumVerticalOffset: CGFloat { get }
    var blocksPaging: Bool { get }
    var onGeometryChange: (@MainActor () -> Void)? { get set }

    func setVerticalOffset(_ offset: CGFloat)
}

extension ScrollablePane {
    public var blocksPaging: Bool {
        false
    }
}

@MainActor
public final class ListPane: ScrollablePane {
    public let list: ListView
    public var onGeometryChange: (@MainActor () -> Void)?

    public var node: ASDisplayNode {
        list
    }

    public var verticalOffset: CGFloat {
        list.contentOffset + list.contentInsets.top
    }

    public var maximumVerticalOffset: CGFloat {
        let insets = list.contentInsets

        return max(0, list.scrollView.contentSize.height + insets.top + insets.bottom - list.bounds.height)
    }

    public init(list: ListView) {
        self.list = list
        list.scrollView.isScrollEnabled = false
        list.scrollView.scrollsToTop = false
        list.onContentSizeChange = { [weak self] _ in
            self?.onGeometryChange?()
        }
    }

    public func setVerticalOffset(_ offset: CGFloat) {
        list.scrollView.contentOffset.y = offset - list.contentInsets.top
    }
}
