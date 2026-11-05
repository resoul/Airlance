import UIKit

extension TabBarController {
    func slide(hidden: Bool, alongside coordinator: any UIViewControllerTransitionCoordinator) {
        isTabBarHidden = hidden
        tabBarView.alpha = 1
        tabBarView.isUserInteractionEnabled = !hidden
        let height = TabBarLayout.reservedHeight(bottomInset: view.safeAreaInsets.bottom)
        let queued = coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else {
                return
            }

            self.tabBarView.transform = hidden ? CGAffineTransform(translationX: 0, y: height + 24) : .identity
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }, completion: { [weak self] context in
            if context.isCancelled {
                self?.isTabBarHidden = !hidden
            }
            self?.applyTabBarVisibility()
        })
        if !queued {
            applyTabBarVisibility()
        }
    }
}
