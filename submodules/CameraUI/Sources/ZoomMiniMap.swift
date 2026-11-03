import CoreMotion
import UIKit

final class ZoomMiniMap: UIView {
    static let width: CGFloat = 92
    static let threshold: CGFloat = 3

    private let motion = CMMotionManager()
    private let viewport = UIView()
    private var snapshot: UIView?
    private var capturedZoom: CGFloat = 1
    private var tangent = CGSize(width: 1, height: 1)
    private var turn = CGPoint.zero
    private var lastTimestamp: TimeInterval?
    private var zoom: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        alpha = 0
        backgroundColor = .black
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        viewport.layer.borderColor = UIColor.systemYellow.cgColor
        viewport.layer.borderWidth = 1.5
        viewport.layer.cornerRadius = 2
        addSubview(viewport)
        motion.deviceMotionUpdateInterval = 1 / 30
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func capture(_ source: UIView, zoom: CGFloat, tangentAtUnitZoom: CGFloat) {
        guard source.bounds.height > 0, let image = source.snapshotView(afterScreenUpdates: false) else {
            return
        }

        snapshot?.removeFromSuperview()
        let scale = bounds.width / source.bounds.width
        image.transform = CGAffineTransform(scaleX: scale, y: scale)
        image.center = CGPoint(x: bounds.midX, y: bounds.midY)
        insertSubview(image, belowSubview: viewport)
        snapshot = image
        capturedZoom = zoom
        let vertical = tangentAtUnitZoom / zoom
        tangent = CGSize(width: vertical * source.bounds.width / source.bounds.height, height: vertical)
        turn = .zero
        lastTimestamp = nil
    }

    func reset() {
        snapshot?.removeFromSuperview()
        snapshot = nil
        update(zoom: 1)
    }

    func update(zoom: CGFloat) {
        self.zoom = zoom
        let isVisible = zoom >= Self.threshold && snapshot != nil
        if isVisible != (alpha > 0) {
            UIView.animate(withDuration: 0.2) {
                self.alpha = isVisible ? 1 : 0
            }
        }
        if isVisible {
            startMotion()
        } else {
            stop()
        }
        placeViewport()
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        lastTimestamp = nil
    }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else {
            return
        }

        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let sample else {
                return
            }

            let rate = sample.rotationRate
            let timestamp = sample.timestamp
            MainActor.assumeIsolated {
                self?.track(rate: rate, timestamp: timestamp)
            }
        }
    }

    private func track(rate: CMRotationRate, timestamp: TimeInterval) {
        defer {
            lastTimestamp = timestamp
        }
        guard let lastTimestamp else {
            return
        }

        let delta = CGFloat(timestamp - lastTimestamp)
        turn.x += CGFloat(rate.y) * delta
        turn.y += CGFloat(rate.x) * delta
        placeViewport()
    }

    private func placeViewport() {
        let fraction = min(capturedZoom / max(zoom, capturedZoom), 1)
        let size = CGSize(width: bounds.width * fraction, height: bounds.height * fraction)
        let offset = CGPoint(
            x: -tan(turn.x) / (2 * tangent.width) * bounds.width,
            y: -tan(turn.y) / (2 * tangent.height) * bounds.height
        )
        let center = CGPoint(
            x: min(max(bounds.midX + offset.x, size.width / 2), bounds.width - size.width / 2),
            y: min(max(bounds.midY + offset.y, size.height / 2), bounds.height - size.height / 2)
        )
        viewport.frame = CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: max(size.width, 6),
            height: max(size.height, 6)
        )
    }
}
