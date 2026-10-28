import UIKit

extension ListView {
    func setupSwipe() {
        let controller = ListSwipeController(container: content.view)
        controller.pan.isEnabled = allowsSwipeActions
        controller.nodeAt = { [weak self] location in
            self?.active.values.first { node in
                node.frame.contains(location)
            }
        }
        controller.actionsFor = { [weak self] id in
            let item = self?.items.first { item in
                item.id == id
            }

            return item?.swipeActions()
        }
        scrollView.addGestureRecognizer(controller.pan)
        scrollView.panGestureRecognizer.require(toFail: controller.pan)
        swipe = controller
    }
}
