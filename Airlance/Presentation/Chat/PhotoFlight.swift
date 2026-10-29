import LiquidUI
import UIKit

@MainActor
final class PhotoFlight {
    struct State {
        let frame: CGRect
        let clip: CGRect
        let corners: MediaCorners
    }

    let container = UIView()

    private let imageView: UIImageView
    private let mask = CAShapeLayer()
    private let animator = SpringAnimator(value: 0, stiffness: 15, dampingRatio: 0.9)
    private var from: State?
    private var to: State?
    private var completion: (@MainActor () -> Void)?

    init(image: UIImage?, in host: UIView, below sibling: UIView) {
        imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.mask = mask
        container.clipsToBounds = true
        container.isUserInteractionEnabled = false
        container.addSubview(imageView)
        host.insertSubview(container, belowSubview: sibling)
        animator.onChange = { [weak self] progress in
            self?.apply(progress)
        }
    }

    func run(from: State, to: State, completion: @escaping @MainActor () -> Void) {
        self.from = from
        self.to = to
        self.completion = completion
        apply(0)
        animator.animate(to: 1)
    }

    private func apply(_ progress: CGFloat) {
        guard let from, let to else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let clip = Self.mix(from.clip, to.clip, progress)
        let frame = Self.mix(from.frame, to.frame, progress)
        container.frame = clip
        imageView.frame = frame.offsetBy(dx: -clip.minX, dy: -clip.minY)
        let corners = Self.mix(from.corners, to.corners, Self.cornerProgress(progress, rounding: to.corners))
        mask.path = MediaRenderer.path(imageView.bounds, corners: corners).cgPath
        CATransaction.commit()
        guard progress == 1 else {
            return
        }

        let completion = completion
        self.completion = nil
        completion?()
    }

    private static func cornerProgress(_ progress: CGFloat, rounding target: MediaCorners) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        let rounds = max(target.topLeft, target.topRight, target.bottomLeft, target.bottomRight) > 0

        return rounds ? 1 - pow(1 - min(1, clamped / 0.6), 3) : pow(clamped, 3)
    }

    private static func mix(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private static func mix(_ from: CGRect, _ to: CGRect, _ progress: CGFloat) -> CGRect {
        CGRect(
            x: mix(from.minX, to.minX, progress),
            y: mix(from.minY, to.minY, progress),
            width: mix(from.width, to.width, progress),
            height: mix(from.height, to.height, progress)
        )
    }

    private static func mix(_ from: MediaCorners, _ to: MediaCorners, _ progress: CGFloat) -> MediaCorners {
        MediaCorners(
            topLeft: mix(from.topLeft, to.topLeft, progress),
            topRight: mix(from.topRight, to.topRight, progress),
            bottomLeft: mix(from.bottomLeft, to.bottomLeft, progress),
            bottomRight: mix(from.bottomRight, to.bottomRight, progress)
        )
    }
}
