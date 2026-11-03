import UIKit

extension TabBarController {
    public var isAccessoryShown: Bool {
        tabBarView.isAccessoryShown
    }

    public func setAccessory(_ view: UIView?, height: CGFloat) {
        tabBarView.setAccessory(view, height: height)
        self.view.setNeedsLayout()
    }

    public func setAccessoryShown(_ isShown: Bool, animated: Bool) {
        guard isShown != tabBarView.isAccessoryShown else {
            return
        }

        tabBarView.isAccessoryShown = isShown
        let accessory = tabBarView.accessory?.view
        let changes = {
            accessory?.alpha = isShown ? 1 : 0
            accessory?.transform = isShown ? .identity : CGAffineTransform(translationX: 0, y: 12)
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        guard animated else {
            changes()

            return
        }

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            changes()
        }
    }
}
