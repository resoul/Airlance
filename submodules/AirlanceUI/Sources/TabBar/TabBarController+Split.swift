import Theme
import UIKit

extension TabBarController {
    public static var splitMinWidth: CGFloat {
        700
    }

    var primaryFrame: CGRect {
        guard isSplit else {
            return view.bounds
        }

        let width = min(max(view.bounds.width * 0.36, 320), 400)

        return CGRect(x: 0, y: 0, width: width, height: view.bounds.height)
    }

    public func setDetail(_ controller: UIViewController) {
        guard controller !== detailViewController else {
            return
        }

        if let detailViewController {
            remove(detailViewController)
        }
        detailViewController = controller
        showDetail()
    }

    func updateSplit() {
        let split = view.bounds.width >= Self.splitMinWidth && traitCollection.horizontalSizeClass == .regular
        guard split != isSplit else {
            return
        }

        isSplit = split
        showDetail()
        onSplitChange?(split)
    }

    func layoutDetail() {
        let primary = primaryFrame
        separator.isHidden = !isSplit
        let hairline = 1 / max(traitCollection.displayScale, 1)
        separator.frame = CGRect(x: primary.maxX, y: 0, width: hairline, height: primary.height)
        detailViewController?.view.frame = CGRect(
            x: primary.maxX,
            y: 0,
            width: view.bounds.width - primary.maxX,
            height: view.bounds.height
        )
    }

    func applySplitTheme(_ theme: AppTheme) {
        separator.backgroundColor = theme.colors.separator
    }

    private func showDetail() {
        guard let detail = detailViewController, isViewLoaded else {
            return
        }
        guard isSplit else {
            remove(detail)

            return
        }
        guard detail.parent !== self else {
            return
        }

        addChild(detail)
        view.insertSubview(detail.view, belowSubview: tabBarView)
        detail.didMove(toParent: self)
        layoutDetail()
    }
}
