import UIKit

extension ToastView {
    private static let dismissDistance: CGFloat = 30
    private static let dismissVelocity: CGFloat = 500

    func installGestures() {
        pan.addTarget(self, action: #selector(panned(_:)))
        addGestureRecognizer(pan)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        hold(true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        hold(false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        if pan.state != .began, pan.state != .changed {
            hold(false)
        }
    }

    override func accessibilityActivate() -> Bool {
        tapped()

        return true
    }

    @objc
    private func tapped() {
        let action = toast.action
        dismiss()
        action?()
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        let towardEdge = toast.edge == .top ? -translation.y : translation.y
        switch gesture.state {
        case .began, .changed:
            hold(true)
            let along = towardEdge > 0 ? towardEdge : towardEdge * 0.25
            drag = CGPoint(x: translation.x * 0.2, y: toast.edge == .top ? -along : along)
            transform = CGAffineTransform(translationX: drag.x, y: drag.y)
        case .ended:
            let velocity = gesture.velocity(in: superview).y
            let velocityTowardEdge = toast.edge == .top ? -velocity : velocity
            drag = .zero
            if towardEdge > Self.dismissDistance || velocityTowardEdge > Self.dismissVelocity {
                dismiss(velocity: max(0, velocityTowardEdge))
            } else {
                settle()
            }
        case .cancelled, .failed:
            drag = .zero
            settle()
        default:
            break
        }
    }

    private func settle() {
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.transform = .identity
        }
        hold(false)
    }

    private func hold(_ held: Bool) {
        guard isHeld != held, isActive else {
            return
        }

        isHeld = held
        if held {
            pauseDismissal()
        } else {
            scheduleDismissal()
        }
    }
}
