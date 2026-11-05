import UIKit

final class PhotoSwipes: NSObject, UIGestureRecognizerDelegate {
    var onSwipe: (@MainActor (Bool) -> Void)?

    init(view: UIView) {
        super.init()
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            swipe.delegate = self
            view.addGestureRecognizer(swipe)
        }
    }

    static func slide(_ layer: CALayer, forward: Bool) {
        let transition = CATransition()
        transition.type = .push
        transition.subtype = forward ? .fromRight : .fromLeft
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(transition, forKey: "photo")
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc
    private func swiped(_ gesture: UISwipeGestureRecognizer) {
        onSwipe?(gesture.direction == .left)
    }
}
