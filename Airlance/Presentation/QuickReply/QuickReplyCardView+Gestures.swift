import UIKit

extension QuickReplyCardView: UITextFieldDelegate, UIGestureRecognizerDelegate {
    func addGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self
        content.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendReply()

        return false
    }

    func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let view = target, view !== self {
            if view === historyClip {
                return false
            }
            if view is UIControl {
                return gesture is UIPanGestureRecognizer && view === name
            }
            target = view.superview
        }

        return isActive
    }

    func openChat() {
        guard isActive else {
            return
        }

        onOpenChat?(draft)
    }

    @objc
    func textChanged() {
        updateControls()
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        if !content.frame.contains(gesture.location(in: self)) {
            dismiss()
        } else {
            beginReply()
        }
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        if isReplying {
            panReply(gesture)

            return
        }

        guard mode == .banner || mode == .entering else {
            return
        }

        let translation = gesture.translation(in: self).y
        switch gesture.state {
        case .began, .changed:
            expiry?.cancel()
            drag = translation < 0 ? translation : translation * 0.55
            animateChange()
        case .ended:
            let velocity = gesture.velocity(in: self).y
            drag = 0
            if translation < -35 || velocity < -650 {
                dismiss()
            } else if translation > 30 {
                beginReply()
            } else {
                scheduleExpiry()
                animateChange()
            }
        default:
            drag = 0
            scheduleExpiry()
            animateChange()
        }
    }

    private func panReply(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self).y
        let distance = max(160, chatHeight - Self.replyHeight)
        switch gesture.state {
        case .began:
            dragStartExpansion = expansion
            dragExpansion = dragStartExpansion
        case .changed:
            let value = dragStartExpansion + translation / distance
            drag = dragStartExpansion < 0.5 && value < 0 ? value * distance : 0
            dragExpansion = min(max(value, 0), 1)
            let armed = value > 0.4
            if armed != isArmed {
                isArmed = armed
                updateControls()
            }
            animateChange()
        default:
            finishReplyPan(gesture, distance: distance)
        }
    }

    private func finishReplyPan(_ gesture: UIPanGestureRecognizer, distance: CGFloat) {
        let velocity = gesture.velocity(in: self).y
        let value = dragExpansion ?? expansion
        expansionSpring.reset(to: value)
        dragExpansion = nil
        isArmed = false
        let isDismissing = gesture.state == .ended && dragStartExpansion < 0.5 && value < 0.01
            && (drag < -35 || velocity < -650)
        drag = 0
        guard !isDismissing else {
            dismiss()

            return
        }

        let projected = value + velocity / distance * 0.25
        setExpanded(gesture.state == .ended ? projected > 0.5 : mode == .expanded, velocity: velocity / distance)
    }
}
