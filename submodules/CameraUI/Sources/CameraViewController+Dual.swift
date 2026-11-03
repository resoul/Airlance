import Haptics
import UIKit

extension CameraViewController {
    private static let pipWidth: CGFloat = 0.32

    var availableModes: [CameraMode] {
        configuration.modes.filter { mode in
            mode != .dual || DualCameraSession.isSupported
        }
    }

    var isRecordingVideo: Bool {
        camera.isRecording || dual?.isRecording == true
    }

    func enterDual() {
        guard dual == nil, let session = DualCameraSession(makeURL: { [camera] in
            camera.newVideoURL()
        }) else {
            return
        }

        camera.stop()
        camera.preview.isHidden = true
        previewHost.layer.insertSublayer(session.backPreview, above: camera.preview)
        pipView.layer.addSublayer(session.frontPreview)
        pipView.clipsToBounds = true
        pipView.layer.cornerRadius = 18
        pipView.layer.cornerCurve = .continuous
        pipView.layer.borderWidth = 2
        pipView.layer.borderColor = UIColor.white.cgColor
        if pipView.gestureRecognizers?.isEmpty ?? true {
            pipView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pipDragged(_:))))
        }
        previewHost.addSubview(pipView)
        if configuration.isMicrophoneAuthorized() {
            session.addAudio()
        }
        dual = session
        layoutDual()
        session.start()
        setZoomChrome(hidden: true)
    }

    func leaveDual() {
        guard let session = dual else {
            return
        }

        session.stop()
        session.backPreview.removeFromSuperlayer()
        session.frontPreview.removeFromSuperlayer()
        pipView.removeFromSuperview()
        dual = nil
        camera.preview.isHidden = false
        camera.start()
        setZoomChrome(hidden: false)
    }

    func layoutDual() {
        guard let dual else {
            return
        }

        let bounds = previewHost.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dual.backPreview.frame = bounds
        let width = bounds.width * Self.pipWidth
        let height = width * 4 / 3
        let origin = CGPoint(
            x: min(max(pipOrigin.x * bounds.width, 12), bounds.width - width - 12),
            y: min(max(pipOrigin.y * bounds.height, 12), bounds.height - height - 12)
        )
        pipView.frame = CGRect(origin: origin, size: CGSize(width: width, height: height))
        dual.frontPreview.frame = pipView.bounds
        CATransaction.commit()
    }

    func beginDual() {
        guard let dual else {
            return
        }

        if configuration.isMicrophoneAuthorized() {
            dual.addAudio()
        }
        dual.startRecording(rotation: camera.captureRotation)
        recordStart = Date()
        shutter.setRecording(true, limit: configuration.videoLimit)
        Haptics.play(.reveal)
        setRecordingChrome(true)
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.tickTimer()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    func finishDual() {
        guard let dual, dual.isRecording else {
            return
        }

        timerTask?.cancel()
        resetLock()
        shutter.setRecording(false, limit: 0)
        shutter.setBusy(true)
        isProcessing = true
        Haptics.play(.tap)
        let bounds = previewHost.bounds
        let pip = CGRect(
            x: pipView.frame.minX / bounds.width,
            y: pipView.frame.minY / bounds.height,
            width: pipView.frame.width / bounds.width,
            height: pipView.frame.height / bounds.height
        )
        dual.stopRecording { [weak self] back, front in
            guard let self else {
                return
            }

            let output = self.camera.newVideoURL()
            Task { [weak self] in
                var result = back
                if let back, let front, await DualComposer.compose(back: back, front: front, pip: pip, to: output) {
                    try? FileManager.default.removeItem(at: back)
                    try? FileManager.default.removeItem(at: front)
                    result = output
                }
                self?.dualFinished(result)
            }
        }
    }

    private func dualFinished(_ url: URL?) {
        isProcessing = false
        shutter.setBusy(false)
        setRecordingChrome(false)
        guard let url else {
            Haptics.play(.error)

            return
        }

        onCapture?(.video(url))
    }

    private func setZoomChrome(hidden: Bool) {
        UIView.animate(withDuration: 0.2) {
            for control in [self.lensBar, self.flipButton, self.flashButton] {
                control.alpha = hidden ? 0 : 1
            }
        }
        for control in [lensBar, flipButton, flashButton] {
            control.isUserInteractionEnabled = !hidden
        }
    }

    @objc
    private func pipDragged(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: previewHost)
        gesture.setTranslation(.zero, in: previewHost)
        let bounds = previewHost.bounds
        pipOrigin.x += translation.x / max(bounds.width, 1)
        pipOrigin.y += translation.y / max(bounds.height, 1)
        layoutDual()
        if gesture.state == .ended {
            pipOrigin = CGPoint(x: pipView.frame.minX / bounds.width, y: pipView.frame.minY / bounds.height)
        }
    }
}
