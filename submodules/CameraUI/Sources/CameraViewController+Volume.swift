import AVKit
import UIKit

extension CameraViewController {
    private static let volumeTapLimit: TimeInterval = 0.25
    private static let volumeRate: CGFloat = 1.022

    func bindVolumeZoom() {
        guard configuration.isVolumeZoomEnabled, #available(iOS 17.2, *) else {
            return
        }

        let interaction = AVCaptureEventInteraction { [weak self] event in
            self?.volumePressed(-1, phase: event.phase)
        } secondary: { [weak self] event in
            self?.volumePressed(1, phase: event.phase)
        }
        view.addInteraction(interaction)
    }

    @available(iOS 17.2, *)
    private func volumePressed(_ direction: Int, phase: AVCaptureEventPhase) {
        guard isCaptureEnabled else {
            return
        }

        switch phase {
        case .began:
            willZoom()
            volumeStart = Date()
            volumeZoom = camera.zoom
            zoomTask?.cancel()
            zoomTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.volumeTapLimit * 1_000_000_000))
                while !Task.isCancelled {
                    self?.holdVolume(direction)
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
            }
        case .ended:
            let isTap = volumeStart.map { start in
                Date().timeIntervalSince(start) < Self.volumeTapLimit
            } ?? false
            zoomTask?.cancel()
            volumeStart = nil
            if isTap {
                stepLens(direction)
            }
        default:
            zoomTask?.cancel()
            volumeStart = nil
        }
    }

    private func holdVolume(_ direction: Int) {
        let range = camera.zoomRange
        let next = volumeZoom * pow(Self.volumeRate, CGFloat(direction))
        volumeZoom = min(max(next, range.lowerBound), range.upperBound)
        applyZoom(volumeZoom)
    }
}
