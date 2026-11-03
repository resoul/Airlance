import Haptics
import UIKit

extension CameraViewController {
    private static let holdDelay: UInt64 = 280_000_000

    func bindGestures() {
        let press = UILongPressGestureRecognizer(target: self, action: #selector(shutterPressed(_:)))
        press.minimumPressDuration = 0
        shutter.addGestureRecognizer(press)
        previewHost.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:))))
        previewHost.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        let flipTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        flipTap.numberOfTapsRequired = 2
        previewHost.addGestureRecognizer(flipTap)
    }

    func flip() {
        guard !camera.isRecording else {
            return
        }

        Haptics.play(.tap)
        UIView.transition(with: previewHost, duration: 0.4, options: .transitionFlipFromLeft) {
            self.camera.switchPosition()
        }
        positionChanged()
        miniMap.reset()
        configureZoom()
    }

    func cycleFlash() {
        let all = CameraSession.Flash.allCases
        let index = all.firstIndex(of: camera.flash) ?? 0
        camera.flash = all[(index + 1) % all.count]
        let configuration = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        flashButton.setImage(UIImage(systemName: camera.flash.symbol, withConfiguration: configuration), for: .normal)
        Haptics.play(.selection)
    }

    @objc
    private func doubleTapped() {
        flip()
    }

    @objc
    private func pinched(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            willZoom()
            zoomTask?.cancel()
            pinchStartZoom = camera.zoom
        }
        applyZoom(pinchStartZoom * gesture.scale)
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: previewHost)
        camera.focus(at: point)
        focusSquare.frame = CGRect(x: point.x - 40, y: point.y - 40, width: 80, height: 80)
        focusSquare.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        focusSquare.alpha = 1
        UIView.animate(withDuration: 0.25) {
            self.focusSquare.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 0.9) {
            self.focusSquare.alpha = 0
        }
        Haptics.play(.selection)
    }

    @objc
    private func shutterPressed(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: view)
        switch gesture.state {
        case .began:
            pressBegan(at: point)
        case .changed:
            dragZoom(to: point)
            trackLock(to: point)
        case .ended:
            pressEnded()
        default:
            shutter.press(false)
            recordTask?.cancel()
            if isBursting {
                finishBurst()
            } else if mode != .loop, !isLocked {
                finishRecording()
            }
        }
    }

    private func pressBegan(at point: CGPoint) {
        ignoresPress = false
        guard isCaptureEnabled, !isProcessing else {
            ignoresPress = true

            return
        }

        guard countdownTask == nil else {
            cancelCountdown()
            ignoresPress = true

            return
        }

        pressStart = (point, Date())
        pressWasRecording = isRecordingVideo
        shutter.press(true)
        guard !pressWasRecording else {
            return
        }

        if mode == .loop {
            recordLoop()

            return
        }

        let mode = mode
        recordTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.holdDelay)
            guard !Task.isCancelled else {
                return
            }

            switch mode {
            case .burst:
                self?.beginBurst()
            case .photo, .video, .dual:
                self?.beginRecording()
                self?.showLockHint()
            case .square, .loop:
                break
            }
        }
    }

    private func pressEnded() {
        shutter.press(false)
        recordTask?.cancel()
        guard isCaptureEnabled, mode != .loop, !isProcessing, !ignoresPress else {
            return
        }

        if isBursting {
            finishBurst()
        } else if isRecordingVideo {
            guard !isLocked || pressWasRecording else {
                return
            }

            finishRecording()
        } else if !pressWasRecording {
            startAfterCountdown { [weak self] in
                guard let self else {
                    return
                }

                self.mode == .video ? self.beginRecording() : self.takePhoto()
            }
        }
    }

    private func dragZoom(to point: CGPoint) {
        guard camera.isRecording, let start = pressStart?.point else {
            return
        }

        let lift = max(0, start.y - point.y)
        applyZoom(recordStartZoom * (1 + lift / 90))
    }

    private func takePhoto() {
        guard isCaptureEnabled else {
            return
        }

        Haptics.play(.tap)
        flashScreen()
        let isSquare = mode == .square
        let preview = previewHost.bounds.size
        camera.capturePhoto { [weak self] image in
            guard let image else {
                return
            }

            self?.onCapture?(.photo(isSquare ? SquareCrop.crop(image, preview: preview) : image))
        }
    }

    func flashScreen() {
        let flash = UIView(frame: view.bounds)
        flash.backgroundColor = .black
        view.insertSubview(flash, aboveSubview: previewHost)
        UIView.animate(withDuration: 0.25) {
            flash.alpha = 0
        } completion: { _ in
            flash.removeFromSuperview()
        }
    }

    private func beginRecording() {
        guard configuration.isMicrophoneAuthorized() else {
            shutter.press(false)
            Task { [weak self] in
                guard let self else {
                    return
                }

                _ = await self.configuration.authorizeMicrophone(self)
            }

            return
        }

        guard mode != .dual else {
            beginDual()

            return
        }

        camera.enableAudio()
        willZoom()
        recordStartZoom = camera.zoom
        camera.startRecording()
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

    func tickTimer() {
        let elapsed = recordStart.map { start in
            Date().timeIntervalSince(start)
        } ?? 0
        let seconds = max(0, Int(elapsed.rounded()))
        timerLabel.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
        if elapsed >= configuration.videoLimit {
            finishRecording()
        }
    }

    private func finishRecording() {
        guard mode != .dual else {
            finishDual()

            return
        }

        guard camera.isRecording else {
            return
        }

        timerTask?.cancel()
        resetLock()
        shutter.setRecording(false, limit: 0)
        setRecordingChrome(false)
        Haptics.play(.tap)
        camera.stopRecording { [weak self] url in
            guard let url else {
                return
            }

            self?.onCapture?(.video(url))
        }
    }

    func setRecordingChrome(_ isRecording: Bool, showsTimer: Bool = true) {
        UIView.animate(withDuration: 0.2) {
            self.timerLabel.alpha = isRecording && showsTimer ? 1 : 0
            self.hintLabel.alpha = 0
            let controls = [
                self.flipButton, self.flashButton, self.closeButton, self.thumbnailButton, self.modeControl,
                self.galleryButton, self.selfTimerButton, self.scanButton,
            ] + [self.hostAccessory].compactMap(\.self)
            for control in controls {
                let hiddenInDual = self.mode == .dual && (control === self.flipButton || control === self.flashButton)
                control.alpha = isRecording || hiddenInDual ? 0 : 1
            }
            if isRecording {
                self.codePill.alpha = 0
            }
        }
    }
}
