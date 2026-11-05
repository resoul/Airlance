import UIKit

final class CrossfadeTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private static let duration: TimeInterval = 0.3

    private let isOpening: Bool

    init(isOpening: Bool) {
        self.isOpening = isOpening
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        Self.duration
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard
            let from = transitionContext.view(forKey: .from),
            let to = transitionContext.view(forKey: .to),
            let controller = transitionContext.viewController(forKey: .to)
        else {
            transitionContext.completeTransition(false)

            return
        }

        let container = transitionContext.containerView
        to.frame = transitionContext.finalFrame(for: controller)
        if isOpening {
            container.addSubview(to)
            to.alpha = 0
        } else {
            container.insertSubview(to, belowSubview: from)
        }
        to.layoutIfNeeded()
        let isOpening = isOpening
        UIView.animate(withDuration: Self.duration, delay: 0, options: [.curveEaseInOut]) {
            if isOpening {
                to.alpha = 1
            } else {
                from.alpha = 0
            }
        } completion: { _ in
            from.alpha = 1
            to.alpha = 1
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
