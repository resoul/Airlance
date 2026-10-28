import UIKit

@MainActor
final class PanGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    var shouldBegin: (@MainActor (UIPanGestureRecognizer) -> Bool)?
    var shouldReceive: (@MainActor () -> Void)?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }

        return shouldBegin?(pan) ?? true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        shouldReceive?()

        return true
    }
}
