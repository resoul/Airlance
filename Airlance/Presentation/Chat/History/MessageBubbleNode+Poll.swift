@preconcurrency import AsyncDisplayKit
import UIKit

extension MessageBubbleNode {
    func growPollBars(_ bars: [ASDisplayNode]) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }

        for (index, bar) in bars.enumerated() {
            let frame = bar.frame
            let width = CASpringAnimation(keyPath: "bounds.size.width")
            width.fromValue = 0
            width.toValue = frame.width
            let position = CASpringAnimation(keyPath: "position.x")
            position.fromValue = frame.minX
            position.toValue = frame.midX
            let group = CAAnimationGroup()
            group.animations = [width, position]
            for animation in [width, position] {
                animation.damping = 16
                animation.initialVelocity = 0
                animation.duration = animation.settlingDuration
            }
            group.duration = width.settlingDuration
            group.beginTime = CACurrentMediaTime() + 0.05 * Double(index)
            group.fillMode = .backwards
            bar.layer.add(group, forKey: "grow")
        }
    }
}

extension MessageBubbleNode {
    func shake() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }

        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -10, 9, -6, 4, -2, 0]
        shake.duration = 0.45
        layer.add(shake, forKey: "shake")
    }
}
