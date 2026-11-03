import Haptics
import UIKit

extension CameraViewController {
    private static let burstLimit = 30
    private static let burstInterval: UInt64 = 140_000_000
    private static let burstSettle: UInt64 = 350_000_000

    func beginBurst() {
        guard !isBursting else {
            return
        }

        isBursting = true
        burstImages = []
        burstLabel.text = "0"
        setRecordingChrome(true, showsTimer: false)
        UIView.animate(withDuration: 0.2) {
            self.burstLabel.alpha = 1
        }
        burstTask = Task { [weak self] in
            var shots = 0
            while !Task.isCancelled, shots < Self.burstLimit {
                self?.shootBurstFrame()
                shots += 1
                try? await Task.sleep(nanoseconds: Self.burstInterval)
            }
            self?.finishBurst()
        }
    }

    private func shootBurstFrame() {
        Haptics.play(.selection)
        camera.capturePhoto(fast: true) { [weak self] image in
            guard let self, let image else {
                return
            }

            self.burstImages.append(image)
            self.burstLabel.text = String(self.burstImages.count)
        }
    }

    func finishBurst() {
        guard isBursting else {
            return
        }

        isBursting = false
        burstTask?.cancel()
        burstTask = nil
        isProcessing = true
        shutter.setBusy(true)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.burstSettle)
            self?.deliverBurst()
        }
    }

    private func deliverBurst() {
        isProcessing = false
        shutter.setBusy(false)
        setRecordingChrome(false)
        UIView.animate(withDuration: 0.2) {
            self.burstLabel.alpha = 0
        }
        let images = burstImages
        burstImages = []
        guard !images.isEmpty else {
            return
        }

        Haptics.play(.success)
        onPick?(images.map(CameraCapture.photo))
    }

    func recordLoop() {
        guard !camera.isRecording, !isProcessing else {
            return
        }

        willZoom()
        recordStartZoom = camera.zoom
        camera.startRecording()
        shutter.setRecording(true, limit: LoopMaker.duration)
        setRecordingChrome(true, showsTimer: false)
        Haptics.play(.reveal)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(LoopMaker.duration * 1_000_000_000))
            self?.stopLoop()
        }
    }

    private func stopLoop() {
        isProcessing = true
        shutter.setRecording(false, limit: 0)
        shutter.setBusy(true)
        camera.stopRecording { [weak self] url in
            guard let self, let url else {
                self?.loopFinished(nil)

                return
            }

            let output = self.camera.newVideoURL()
            Task { [weak self] in
                let made = await LoopMaker.make(from: url, to: output)
                try? FileManager.default.removeItem(at: url)
                self?.loopFinished(made ? output : nil)
            }
        }
    }

    private func loopFinished(_ url: URL?) {
        isProcessing = false
        shutter.setBusy(false)
        setRecordingChrome(false)
        guard let url else {
            Haptics.play(.error)

            return
        }

        Haptics.play(.success)
        onCapture?(.video(url))
    }
}
