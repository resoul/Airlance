import UIKit

extension TabBarView {
    func updateMenuGesture() {
        menuGesture.isEnabled = menuProvider != nil
    }

    @objc
    func pressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let theme, let container = superview,
              let index = index(at: gesture.location(in: background)),
              iconViews.indices.contains(index),
              let items = menuProvider?(index) else {
            return
        }

        let icon = iconViews[index].convert(iconViews[index].bounds, to: container)
        let bar = background.convert(background.bounds, to: container)
        let anchor = CGRect(x: icon.minX, y: bar.minY, width: icon.width, height: bar.height)
        PopupMenu.show(items, theme: theme, from: anchor, in: container, below: self)
    }
}
