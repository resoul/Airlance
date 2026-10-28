import Haptics
import UIKit

@MainActor
final class ListSwipeController: NSObject, UIGestureRecognizerDelegate {
    private static let buttonWidth: CGFloat = 76
    private static let fullRatio: CGFloat = 0.58

    let pan = UIPanGestureRecognizer()

    var nodeAt: (@MainActor (CGPoint) -> ListItemNode?)?
    var actionsFor: (@MainActor (String) -> ListSwipeActions?)?

    private weak var container: UIView?
    private weak var node: ListItemNode?
    private var actions = ListSwipeActions()
    private var buttons: ListSwipeButtonsView?
    private var offset: CGFloat = 0
    private var startOffset: CGFloat = 0
    private var isFull = false

    var isOpen: Bool {
        node != nil
    }

    init(container: UIView) {
        self.container = container
        super.init()
        pan.addTarget(self, action: #selector(panned(_:)))
        pan.delegate = self
        pan.isEnabled = false
    }

    func close(animated: Bool) {
        guard let node else {
            return
        }

        let buttons = buttons
        self.node = nil
        self.buttons = nil
        offset = 0
        isFull = false
        let changes = {
            node.view.transform = .identity
            buttons?.layout(offset: 0, isFull: false)
        }
        guard animated else {
            changes()
            buttons?.removeFromSuperview()

            return
        }

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            changes()
        } completion: { _ in
            buttons?.removeFromSuperview()
        }
    }

    func nodeWillRecycle(_ recycled: ListItemNode) {
        if recycled === node {
            close(animated: false)
        }
        recycled.view.transform = .identity
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let velocity = pan.velocity(in: pan.view)
        guard abs(velocity.x) > abs(velocity.y) * 1.3, let container else {
            return false
        }

        let location = pan.location(in: container)
        if let node, node.frame.contains(location) {
            return true
        }

        guard let candidate = nodeAt?(location), let id = candidate.itemID, let actions = actionsFor?(id) else {
            return false
        }

        return velocity.x < 0 ? !actions.trailing.isEmpty : !actions.leading.isEmpty
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            Haptics.prepare(.threshold)
            begin(at: gesture.location(in: container))
        case .changed:
            move(translation: gesture.translation(in: container).x)
        case .ended, .cancelled:
            finish(velocity: gesture.velocity(in: container).x, ended: gesture.state == .ended)
        default:
            break
        }
    }

    private func begin(at location: CGPoint) {
        if let node, node.frame.contains(location) {
            startOffset = offset

            return
        }

        close(animated: true)
        guard let container, let candidate = nodeAt?(location), let id = candidate.itemID,
              let actions = actionsFor?(id) else {
            return
        }

        let buttons = ListSwipeButtonsView(actions: actions) { [weak self] action in
            self?.perform(action)
        }
        buttons.frame = candidate.frame
        container.insertSubview(buttons, belowSubview: candidate.view)
        self.actions = actions
        self.buttons = buttons
        node = candidate
        offset = 0
        startOffset = 0
    }

    private func move(translation: CGFloat) {
        guard let node else {
            return
        }

        var proposed = startOffset + translation
        if proposed > 0, actions.leading.isEmpty || proposed < 0, actions.trailing.isEmpty {
            proposed = 0
        }
        let count = CGFloat(proposed < 0 ? actions.trailing.count : actions.leading.count)
        let limit = Self.buttonWidth * count
        if abs(proposed) > limit {
            proposed = (limit + (abs(proposed) - limit) * 0.75) * (proposed < 0 ? -1 : 1)
        }
        offset = proposed
        let full = abs(offset) > node.bounds.width * Self.fullRatio
        if full != isFull {
            isFull = full
            Haptics.play(.threshold)
            UIView.animate(withDuration: 0.25) {
                self.buttons?.layout(offset: self.offset, isFull: full)
            }
        }
        node.view.transform = CGAffineTransform(translationX: offset, y: 0)
        buttons?.layout(offset: offset, isFull: isFull)
    }

    private func finish(velocity: CGFloat, ended: Bool) {
        guard let node else {
            return
        }

        if isFull, ended {
            let action = offset < 0 ? actions.trailing.last : actions.leading.first
            close(animated: true)
            if let action {
                action.handler()
            }

            return
        }

        let count = CGFloat(offset < 0 ? actions.trailing.count : actions.leading.count)
        let open = abs(offset) > Self.buttonWidth * 0.5 && (offset < 0 ? velocity < 300 : velocity > -300)
        guard open else {
            close(animated: true)

            return
        }

        offset = Self.buttonWidth * count * (offset < 0 ? -1 : 1)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            node.view.transform = CGAffineTransform(translationX: self.offset, y: 0)
            self.buttons?.layout(offset: self.offset, isFull: false)
        }
    }

    private func perform(_ action: ListSwipeAction) {
        close(animated: true)
        action.handler()
    }
}
