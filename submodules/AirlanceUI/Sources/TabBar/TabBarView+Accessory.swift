import UIKit

extension TabBarView {
    static let accessoryGap: CGFloat = 8

    var accessoryReserve: CGFloat {
        guard isAccessoryShown, let accessory else {
            return 0
        }

        return accessory.height + Self.accessoryGap
    }

    func setAccessory(_ view: UIView?, height: CGFloat) {
        accessory?.view.removeFromSuperview()
        accessory = view.map { view in
            (view, height)
        }
        if let view {
            addSubview(view)
            view.alpha = isAccessoryShown ? 1 : 0
        }
        setNeedsLayout()
    }

    func layoutAccessory(above bar: CGRect) {
        guard let accessory else {
            return
        }

        let margin = TabBarLayout.sideMargin
        let y = bar.minY - Self.accessoryGap - accessory.height
        accessory.view.frame = CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: accessory.height)
    }

    func accessoryContains(_ point: CGPoint) -> Bool {
        guard isAccessoryShown, let view = accessory?.view else {
            return false
        }

        return view.frame.contains(point)
    }
}
