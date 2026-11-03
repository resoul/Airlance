import UIKit

@MainActor
public final class StoryViewerTransition: NSObject, UIViewControllerTransitioningDelegate {
    weak var viewer: StoryViewerController?
    weak var source: (any StoryTransitionSource)?

    public func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        StoryViewerAnimator(transition: self, isPresenting: true)
    }

    public func animationController(
        forDismissed dismissed: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        StoryViewerAnimator(transition: self, isPresenting: false)
    }

    func sourceFrame() -> CGRect? {
        guard let peerID = viewer?.currentPeerID else {
            return nil
        }

        return source?.storyAvatarFrame(for: peerID)
    }
}

@MainActor
private final class StoryViewerAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let transition: StoryViewerTransition
    private let isPresenting: Bool

    init(transition: StoryViewerTransition, isPresenting: Bool) {
        self.transition = transition
        self.isPresenting = isPresenting
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0.5
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let viewer = transition.viewer else {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)

            return
        }

        let source = transition.sourceFrame()
        if isPresenting {
            guard let presented = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)

                return
            }

            presented.frame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to) ?? viewer)
            transitionContext.containerView.addSubview(presented)
            viewer.beginOpening(from: source) {
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        } else {
            let dismissed = transitionContext.view(forKey: .from)
            viewer.beginClosing(to: source) {
                dismissed?.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
}
