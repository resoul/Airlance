import Haptics
import UIKit

extension CameraViewController {
    private static let detentWidth: CGFloat = 0.045

    func setUpZoom() {
        lensBar.onSelect = { [weak self] stop in
            self?.selectLens(stop)
        }
        lensBar.onStep = { [weak self] direction in
            self?.stepLens(direction)
        }
        lensBar.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(lensPanned(_:))))
        lensBar.accessibilityLabel = configuration.strings.zoom
        zoomDial.alpha = 0
        configureZoom()
        bindVolumeZoom()
    }

    func configureZoom() {
        let stops = camera.lensStops
        lensBar.configure(stops: stops, zoom: camera.zoom)
        zoomDial.configure(range: camera.zoomRange, stops: stops)
        view.setNeedsLayout()
        zoomChanged()
    }

    func willZoom() {
        guard camera.position == .back, camera.zoom < 1.6 else {
            return
        }

        miniMap.capture(previewHost, zoom: camera.zoom, tangentAtUnitZoom: camera.tangentAtUnitZoom)
    }

    func applyZoom(_ requested: CGFloat) {
        let stop = camera.lensStops.first { stop in
            abs(log(requested / stop)) < Self.detentWidth
        }
        if let stop, stop != detent {
            Haptics.play(.selection)
        }
        detent = stop
        camera.setZoom(stop ?? requested)
        zoomChanged()
    }

    func zoomChanged() {
        let zoom = camera.zoom
        lensBar.update(zoom: zoom)
        zoomDial.update(zoom: zoom)
        miniMap.update(zoom: zoom)
    }

    func selectLens(_ stop: CGFloat) {
        willZoom()
        Haptics.play(.selection)
        detent = stop
        let from = camera.zoom
        let frames = UIAccessibility.isReduceMotionEnabled ? 1 : 14
        zoomTask?.cancel()
        zoomTask = Task { [weak self] in
            for frame in 1...frames {
                guard !Task.isCancelled, let self else {
                    return
                }

                let eased = 1 - pow(1 - CGFloat(frame) / CGFloat(frames), 3)
                self.camera.setZoom(from * pow(stop / from, eased))
                self.zoomChanged()
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    func stepLens(_ direction: Int) {
        let zoom = camera.zoom
        let stops = camera.lensStops
        let next = direction > 0
            ? stops.first { stop in
                stop > zoom * 1.02
            }
            : stops.last { stop in
                stop < zoom / 1.02
            }
        if let next {
            selectLens(next)
        }
    }

    @objc
    private func lensPanned(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            willZoom()
            zoomTask?.cancel()
            dialTask?.cancel()
            dialStartZoom = camera.zoom
            setDial(visible: true)
        case .changed:
            applyZoom(zoomDial.zoom(from: dialStartZoom, drag: gesture.translation(in: view).x))
        default:
            dialTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else {
                    return
                }

                self?.setDial(visible: false)
            }
        }
    }

    private func setDial(visible: Bool) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .beginFromCurrentState) {
            self.zoomDial.alpha = visible ? 1 : 0
            self.zoomDial.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: 24)
            self.lensBar.alpha = visible ? 0.02 : 1
        }
    }
}
