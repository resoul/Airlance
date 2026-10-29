import UIKit

extension MessageBubbleNode {
    func startDownload(duration: TimeInterval) {
        removeDownload()
        guard let frame = fileIconFrame else {
            return
        }

        let ring = CAShapeLayer()
        ring.frame = frame
        ring.path = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: frame.size).insetBy(dx: 3, dy: 3),
            cornerRadius: 9
        ).cgPath
        ring.fillColor = UIColor.black.withAlphaComponent(0.25).cgColor
        ring.strokeColor = UIColor.white.cgColor
        ring.lineWidth = 3
        ring.lineCap = .round
        ring.strokeEnd = 1
        let progress = CABasicAnimation(keyPath: "strokeEnd")
        progress.fromValue = 0
        progress.toValue = 1
        progress.duration = duration
        progress.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ring.add(progress, forKey: "progress")
        layer.addSublayer(ring)
        downloadRing = ring
    }

    func removeDownload() {
        downloadRing?.removeFromSuperlayer()
        downloadRing = nil
    }
}
