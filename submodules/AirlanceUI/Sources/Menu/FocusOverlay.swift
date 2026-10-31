import UIKit

@MainActor
public protocol FocusOverlay: UIView {}

extension UIWindow {
    public var hasFocusOverlay: Bool {
        let roots = subviews + (rootViewController?.view.subviews ?? [])

        return roots.contains { view in
            view is any FocusOverlay && !view.isHidden
        }
    }
}
