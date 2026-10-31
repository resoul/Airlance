import UIKit

extension ListView {
    func setupLongPress() {
        let press = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        press.minimumPressDuration = 0.4
        press.delegate = self
        scrollView.addGestureRecognizer(press)
    }

    @objc
    private func longPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else {
            onLongPressMove?(gesture)

            return
        }

        guard swipe?.isOpen != true else {
            return
        }

        let location = gesture.location(in: content.view)
        let node = active.values.first { node in
            node.frame.contains(location)
        }
        guard let node, let id = node.itemID, let item = items.first(where: { item in
            item.id == id
        }) else {
            return
        }

        item.longPressed(node: node, at: gesture.location(in: node.view))
    }
}

extension ListView {
    public func itemID(at point: CGPoint, in space: UIView) -> String? {
        let location = space.convert(point, to: content.view)

        return active.values.first { node in
            node.frame.contains(location)
        }?.itemID
    }
}
