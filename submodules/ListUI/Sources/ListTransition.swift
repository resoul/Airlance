import UIKit

@MainActor
enum ListTransition {
    static func animate(
        _ animated: Bool,
        changes: @escaping @MainActor () -> Void,
        completion: (@MainActor (Bool) -> Void)? = nil
    ) {
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            UIView.performWithoutAnimation(changes)
            completion?(true)

            return
        }

        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: changes,
            completion: completion
        )
    }
}
