import Theme
import UIKit

@MainActor
extension Toast {
    public func show(theme: AppTheme, in view: UIView) {
        let container = Self.container(for: view)
        let host = container.subviews.lazy.compactMap { subview in
            subview as? ToastHostView
        }.first ?? ToastHostView(frame: container.bounds)
        if host.superview !== container {
            container.addSubview(host)
        }
        container.bringSubviewToFront(host)
        host.enqueue(self, theme: theme)
    }

    public static func dismissAll(in view: UIView) {
        let container = container(for: view)
        for case let host as ToastHostView in container.subviews {
            host.dismissAll()
        }
    }

    private static func container(for view: UIView) -> UIView {
        if view is UIScrollView, let superview = view.superview {
            return superview
        }

        return view
    }
}
