import LiquidUI
import UIKit

extension VoiceRecorderView {
    func step(_ deltaTime: CFTimeInterval) {
        let elapsed = recording.duration
        let target = isFinished ? 0 : recording.level
        let seconds = Int(elapsed)
        timeLabel.text = String(format: "%d:%02d,%d", seconds / 60, seconds % 60, Int(elapsed * 10) % 10)
        scale.step(toward: isFinished ? 0 : 1, deltaTime: deltaTime)
        level.step(toward: target, deltaTime: deltaTime)
        let rate = min(1, CGFloat(deltaTime) * 14)
        follow.x += (finger.x * 0.3 - follow.x) * rate
        follow.y += (finger.y * 0.3 - follow.y) * rate
        phase += CGFloat(deltaTime) * (1.2 + level.value * 3)

        let size = max(scale.value, 0)
        let center = CGPoint(x: buttonCenter.x + follow.x, y: buttonCenter.y + follow.y)
        let radius = (40 + level.value * 14) * size
        var blobs = [Self.circle(center, radius: radius, blend: 0)]
        for index in 0..<4 {
            let angle = phase * (index % 2 == 0 ? 1 : -0.7) + CGFloat(index) * .pi / 2
            let distance = radius * 0.78 + level.value * 16 * size
            let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            blobs.append(Self.circle(point, radius: (9 + level.value * 9) * size, blend: 14))
        }
        canvas.blobs = blobs
        let pulled = hypot(follow.x, follow.y)
        canvas.bridges = pulled > 4 ? [
            LiquidBridge(from: buttonCenter, to: center, startRadius: 16 * size, endRadius: radius * 0.6, blend: 10),
        ] : []
        mic.center = center
        let iconScale = 0.8 + 0.2 * min(size, 1.2)
        mic.transform = CGAffineTransform(scaleX: iconScale, y: iconScale)
        if isFinished, scale.value < 0.02 {
            canvas.blobs = []
            canvas.bridges = []
            canvas.render()
            canvas.stopFrames()
        }
    }

    func playBin() {
        dot.layer.removeAllAnimations()
        dot.isHidden = true
        timeLabel.alpha = 0
        let trash = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let bin = UIImageView(image: UIImage(systemName: "trash", withConfiguration: trash))
        bin.tintColor = theme.colors.destructive
        bin.contentMode = .center
        bin.frame = CGRect(x: 6, y: 52, width: 36, height: 36)
        bin.alpha = 0
        panel.addSubview(bin)
        let flying = UIImageView(image: UIImage(systemName: "mic.fill"))
        flying.tintColor = theme.colors.destructive
        flying.frame = CGRect(x: 14, y: 16, width: 18, height: 20)
        panel.addSubview(flying)
        UIView.animate(withDuration: 0.25) {
            bin.alpha = 1
            bin.frame.origin.y = 8
        }
        UIView.animateKeyframes(withDuration: 0.6, delay: 0) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.45) {
                flying.center.y -= 60
                flying.transform = CGAffineTransform(rotationAngle: .pi)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.45, relativeDuration: 0.55) {
                flying.center = CGPoint(x: bin.center.x, y: 26)
                flying.transform = CGAffineTransform(rotationAngle: .pi * 2).scaledBy(x: 0.3, y: 0.3)
                flying.alpha = 0.2
            }
        } completion: { _ in
            MainActor.assumeIsolated {
                flying.removeFromSuperview()
                Self.closeBin(bin)
            }
        }
    }

    private static func closeBin(_ bin: UIImageView) {
        let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wobble.values = [0, -0.25, 0.2, -0.1, 0]
        wobble.duration = 0.35
        bin.layer.add(wobble, forKey: "wobble")
        UIView.animate(withDuration: 0.25, delay: 0.3) {
            bin.frame.origin.y = 52
        }
    }

    private static func circle(_ center: CGPoint, radius: CGFloat, blend: CGFloat) -> LiquidBlob {
        let frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        return LiquidBlob(frame: frame, cornerRadius: radius, blend: blend)
    }
}
