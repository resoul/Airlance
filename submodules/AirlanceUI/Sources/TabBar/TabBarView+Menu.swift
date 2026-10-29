import UIKit

extension TabBarView {
    func updateMenuGesture() {
        menuGesture.isEnabled = menuProvider != nil
    }

    @objc
    func pressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            showMenu(gesture)
        case .changed, .ended:
            let ended = gesture.state == .ended
            if let menu = activeMenu {
                menu.track(menu.location(of: gesture), ended: ended)
            }
            if ended {
                activeMenu = nil
            }
        default:
            activeMenu?.track(nil, ended: true)
            activeMenu = nil
        }
    }

    private func showMenu(_ gesture: UILongPressGestureRecognizer) {
        guard let theme, let container = superview,
              let index = index(at: gesture.location(in: background)),
              iconViews.indices.contains(index),
              let items = menuProvider?(index) else {
            return
        }

        let icon = iconViews[index].convert(iconViews[index].bounds, to: container)
        let bar = background.convert(background.bounds, to: container)
        let anchor = CGRect(x: icon.minX, y: bar.minY, width: icon.width, height: bar.height)
        activeMenu = PopupMenu.show(items, theme: theme, from: anchor, in: container, below: self)
    }
}
