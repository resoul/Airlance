import UIKit

extension StoryEditorView {
    func setUpMediaGestures() {
        let recognizers: [UIGestureRecognizer] = [
            UIPinchGestureRecognizer(target: self, action: #selector(mediaPinched(_:))),
            UIRotationGestureRecognizer(target: self, action: #selector(mediaRotated(_:))),
            UIPanGestureRecognizer(target: self, action: #selector(mediaPanned(_:))),
        ]
        for recognizer in recognizers {
            recognizer.delegate = self
            addGestureRecognizer(recognizer)
        }
        let reset = UITapGestureRecognizer(target: self, action: #selector(mediaReset))
        reset.numberOfTapsRequired = 2
        addGestureRecognizer(reset)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer.view === self && otherGestureRecognizer.view === self
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer.view === self else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        return mode == .idle && textEditor == nil && stickerPicker == nil
    }

    private func applyMediaTransform() {
        mediaView.transform = mediaTransform.affine(in: bounds.size)
    }

    @objc
    private func mediaPinched(_ gesture: UIPinchGestureRecognizer) {
        mediaTransform.scale = min(max(mediaTransform.scale * gesture.scale, 0.5), 6)
        gesture.scale = 1
        applyMediaTransform()
    }

    @objc
    private func mediaRotated(_ gesture: UIRotationGestureRecognizer) {
        mediaTransform.rotation += gesture.rotation
        gesture.rotation = 0
        applyMediaTransform()
    }

    @objc
    private func mediaPanned(_ gesture: UIPanGestureRecognizer) {
        let shift = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        mediaTransform.offset.x += shift.x / max(bounds.width, 1)
        mediaTransform.offset.y += shift.y / max(bounds.height, 1)
        applyMediaTransform()
    }

    @objc
    private func mediaReset() {
        guard !mediaTransform.isIdentity else {
            return
        }

        mediaTransform = StoryMediaTransform()
        UIView.animate(withDuration: 0.3) {
            self.applyMediaTransform()
        }
    }
}
