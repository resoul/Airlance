import UIKit

extension StoryViewerController {
    func setupGestures() {
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(holding(_:)))
        hold.minimumPressDuration = 0.2
        view.addGestureRecognizer(hold)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.require(toFail: hold)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panned(_:))))
    }

    func requestClose() {
        guard !isCloseRequested else {
            return
        }

        isCloseRequested = true
        page?.media.setPaused(true)
        onClose?()
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        guard phase == .open, !isTurning, !isCloseRequested else {
            return
        }

        if gesture.location(in: view).x < view.bounds.width * 0.3 {
            previous()
        } else {
            next()
        }
    }

    @objc
    private func holding(_ gesture: UILongPressGestureRecognizer) {
        isHeld = gesture.state == .began || gesture.state == .changed
        page?.media.setPaused(isHeld)
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        guard phase == .open, !isCloseRequested else {
            return
        }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        switch gesture.state {
        case .began:
            isHorizontalPan = abs(velocity.x) > abs(velocity.y)
            isDragging = !isHorizontalPan
            page?.media.setPaused(true)
        case .changed:
            if !isHorizontalPan {
                drag(translation)
            }
        default:
            endPan(translation: translation, velocity: velocity)
        }
    }

    private func drag(_ translation: CGPoint) {
        let bounds = view.bounds
        let offset = max(translation.y, 0)
        let scale = 1 - min(offset, 500) / 1400
        let width = bounds.width * scale
        let height = bounds.height * scale
        let rect = CGRect(
            x: bounds.midX - width / 2 + translation.x * 0.4,
            y: offset + (bounds.height - height) / 2,
            width: width,
            height: height
        )
        top.reset(to: rect.minY)
        bottom.reset(to: rect.maxY)
        left.reset(to: rect.minX)
        right.reset(to: rect.maxX)
        corner.reset(to: min(offset / 4, 36))
        applyStage()
    }

    private func endPan(translation: CGPoint, velocity: CGPoint) {
        isDragging = false
        if isHorizontalPan {
            page?.media.setPaused(false)
            if translation.x < -60 || velocity.x < -500 {
                turn(to: authorIndex + 1, forward: true)
            } else if translation.x > 60 || velocity.x > 500 {
                turn(to: authorIndex - 1, forward: false)
            }

            return
        }

        if translation.y > 110 || velocity.y > 900 {
            requestClose()
        } else {
            page?.media.setPaused(false)
            driver.start()
        }
    }
}
