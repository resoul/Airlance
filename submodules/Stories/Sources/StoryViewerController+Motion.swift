import Haptics
import LiquidUI
import UIKit

extension StoryViewerController {
    func beginOpening(from source: CGRect?, completion: @escaping @MainActor () -> Void) {
        view.layoutIfNeeded()
        let start = startRect(for: source)
        reset(to: start)
        phase = .opening
        goal = view.bounds
        phaseCompletion = completion
        applyStage()
        driver.start()
        Haptics.play(.reveal)
    }

    func beginClosing(to source: CGRect?, completion: @escaping @MainActor () -> Void) {
        page?.media.setPaused(true)
        phase = .closing
        isDragging = false
        goal = startRect(for: source)
        phaseCompletion = completion
        driver.start()
    }

    func tick(_ deltaTime: CFTimeInterval) {
        if !isDragging {
            top.step(toward: goal.minY, deltaTime: deltaTime)
            bottom.step(toward: goal.maxY, deltaTime: deltaTime)
            left.step(toward: goal.minX, deltaTime: deltaTime)
            right.step(toward: goal.maxX, deltaTime: deltaTime)
            corner.step(toward: phase == .closing ? goal.width / 2 : 0, deltaTime: deltaTime)
        }
        if phase == .open, !isHeld, !isDragging, !isTurning, !isCloseRequested {
            advance(deltaTime)
        }
        applyStage()
        guard phase != .open, !isDragging, isSettled else {
            return
        }

        if phase == .opening {
            phase = .open
        } else {
            driver.stop()
        }
        let completion = phaseCompletion
        phaseCompletion = nil
        completion?()
    }

    func applyStage() {
        let bounds = view.bounds
        guard bounds.width > 0 else {
            return
        }

        let rect = CGRect(
            x: left.value,
            y: top.value,
            width: max(right.value - left.value, 1),
            height: max(bottom.value - top.value, 1)
        )
        let scale = max(rect.width / bounds.width, rect.height / bounds.height)
        stage.transform = CGAffineTransform(translationX: rect.midX - bounds.midX, y: rect.midY - bounds.midY)
            .scaledBy(x: scale, y: scale)
        let local = CGRect(
            x: bounds.midX - rect.width / scale / 2,
            y: bounds.midY - rect.height / scale / 2,
            width: rect.width / scale,
            height: rect.height / scale
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stageMask.path = UIBezierPath(roundedRect: local, cornerRadius: max(corner.value, 0) / scale).cgPath
        CATransaction.commit()

        let openness = min(1, rect.height / bounds.height)
        dim.alpha = openness * (phase == .closing ? 0.6 : 1)
        stage.alpha = fadesWithSource ? min(1, openness * 3) : 1
    }

    func next() {
        guard let page else {
            return
        }

        if page.itemIndex + 1 < page.author.items.count {
            show(page.itemIndex + 1, on: page)
        } else if authorIndex + 1 < authors.count {
            turn(to: authorIndex + 1, forward: true)
        } else {
            requestClose()
        }
    }

    func previous() {
        guard let page else {
            return
        }

        if page.itemIndex > 0 {
            show(page.itemIndex - 1, on: page)
        } else if authorIndex > 0 {
            turn(to: authorIndex - 1, forward: false)
        } else {
            show(0, on: page)
        }
    }

    func turn(to index: Int, forward: Bool) {
        guard authors.indices.contains(index), !isTurning else {
            return
        }

        isTurning = true
        let outgoing = page
        let incoming = makePage(for: authors[index])
        incoming.bounds = stage.bounds
        incoming.center = CGPoint(x: stage.bounds.midX, y: stage.bounds.midY)
        stage.addSubview(incoming)
        outgoing?.media.setPaused(true)

        let width = stage.bounds.width
        let quarter = CGFloat.pi / 2 * (forward ? 1 : -1)
        incoming.layer.transform = Self.face(quarter, width: width)
        incoming.shade.alpha = 0.6
        page = incoming
        authorIndex = index
        progress = 0
        Haptics.play(.tap)
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.2,
            animations: {
                incoming.layer.transform = CATransform3DIdentity
                incoming.shade.alpha = 0
                outgoing?.layer.transform = Self.face(-quarter, width: width)
                outgoing?.shade.alpha = 0.6
            },
            completion: { [weak self] _ in
                outgoing?.media.stop()
                outgoing?.removeFromSuperview()
                self?.isTurning = false
            }
        )
    }

    private var isSettled: Bool {
        let tolerance: CGFloat = 0.5

        return top.isSettled(at: goal.minY, tolerance: tolerance)
            && bottom.isSettled(at: goal.maxY, tolerance: tolerance)
            && left.isSettled(at: goal.minX, tolerance: tolerance)
            && right.isSettled(at: goal.maxX, tolerance: tolerance)
    }

    private func advance(_ deltaTime: CFTimeInterval) {
        guard let page, let item = page.item else {
            return
        }

        if let video = page.media.videoProgress {
            progress = video
        } else if page.media.isReady {
            progress += CGFloat(deltaTime / item.duration)
        }
        page.setProgress(progress)
        if progress >= 0.999 {
            next()
        }
    }

    private func show(_ index: Int, on page: StoryPageView) {
        progress = 0
        page.show(index)
        onSeen?(page.author.id, index)
        Haptics.play(.selection)
    }

    private func startRect(for source: CGRect?) -> CGRect {
        if let source, source.width > 1 {
            fadesWithSource = false

            return source
        }

        fadesWithSource = true
        let bounds = view.bounds

        return CGRect(x: bounds.midX - 30, y: bounds.midY - 30, width: 60, height: 60)
    }

    private func reset(to rect: CGRect) {
        top.reset(to: rect.minY)
        bottom.reset(to: rect.maxY)
        left.reset(to: rect.minX)
        right.reset(to: rect.maxX)
        corner.reset(to: rect.width / 2)
    }

    private static func face(_ angle: CGFloat, width: CGFloat) -> CATransform3D {
        let pushed = CATransform3DMakeTranslation(0, 0, -width / 2)

        return CATransform3DTranslate(CATransform3DRotate(pushed, angle, 0, 1, 0), 0, 0, width / 2)
    }
}
