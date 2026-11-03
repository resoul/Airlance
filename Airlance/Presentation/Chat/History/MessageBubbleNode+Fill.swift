import UIKit

extension MessageBubbleNode {
    func layoutGradient(_ bubble: CGRect, path: CGPath?) {
        guard let gradient, bounds.height > 0 else {
            gradientLayer.isHidden = true

            return
        }

        gradientLayer.isHidden = false
        gradientLayer.frame = bounds
        gradientMask.frame = bounds
        gradientMask.path = path
        gradientLayer.colors = gradient.map { color in
            color.resolvedColor(with: view.traitCollection).cgColor
        }
        gradientLayer.startPoint = CGPoint(x: 0.5, y: bubble.minY / bounds.height)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: max(bubble.maxY, bubble.minY + 1) / bounds.height)
    }
}
