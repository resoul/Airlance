import Haptics
import UIKit

enum MessageEffect: String, CaseIterable {
    case confetti = "🎉"
    case hearts = "❤️"
    case fire = "🔥"
    case like = "👍"
    case laugh = "😂"
    case balloons = "🎈"

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .confetti:
            strings.chatEffectConfetti
        case .hearts:
            strings.chatEffectHearts
        case .fire:
            strings.chatEffectFire
        case .like:
            strings.chatEffectLike
        case .laugh:
            strings.chatEffectLaugh
        case .balloons:
            strings.chatEffectBalloons
        }
    }

    var floats: Bool {
        self == .balloons || self == .hearts
    }
}

@MainActor
enum MessageEffectPlayer {
    private static let confettiColors: [UIColor] = [
        .systemPink, .systemYellow, .systemTeal, .systemPurple, .systemOrange, .systemGreen,
    ]

    static func play(_ emoji: String, from rect: CGRect, in view: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }

        let effect = MessageEffect(rawValue: emoji)
        let emitter = CAEmitterLayer()
        emitter.frame = view.bounds
        emitter.emitterPosition = CGPoint(x: rect.midX, y: rect.midY)
        emitter.emitterShape = .rectangle
        emitter.emitterSize = rect.size
        emitter.beginTime = CACurrentMediaTime()
        var cells = [cell(image(for: emoji, size: 34), floats: effect?.floats ?? false)]
        if effect == .confetti {
            cells += confettiColors.map(confetti)
        }
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        pop(emoji, at: CGPoint(x: rect.midX, y: rect.midY), in: view)
        Haptics.play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            emitter.removeFromSuperlayer()
        }
    }

    private static func cell(_ image: UIImage?, floats: Bool) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image?.cgImage
        cell.birthRate = 26
        cell.lifetime = 2.6
        cell.velocity = floats ? 220 : 420
        cell.velocityRange = 140
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 2.6
        cell.yAcceleration = floats ? -60 : 620
        cell.scale = 0.7
        cell.scaleRange = 0.35
        cell.spin = 0
        cell.spinRange = floats ? 1 : 4
        cell.alphaSpeed = -0.35

        return cell
    }

    private static func confetti(_ color: UIColor) -> CAEmitterCell {
        let cell = self.cell(swatch(color), floats: false)
        cell.birthRate = 14
        cell.scale = 1
        cell.spinRange = 8

        return cell
    }

    private static func pop(_ emoji: String, at center: CGPoint, in view: UIView) {
        let label = UILabel()
        label.text = emoji
        label.font = .systemFont(ofSize: 84)
        label.sizeToFit()
        label.center = center
        label.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        view.addSubview(label)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0) {
            label.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        } completion: { _ in
            UIView.animate(withDuration: 0.35) {
                label.alpha = 0
                label.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }

    static func image(for emoji: String, size: CGFloat) -> UIImage? {
        let text = emoji as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size)]
        let bounds = text.size(withAttributes: attributes)
        guard bounds.width > 0 else {
            return nil
        }

        return UIGraphicsImageRenderer(size: bounds).image { _ in
            text.draw(at: .zero, withAttributes: attributes)
        }
    }

    private static func swatch(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 12)).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 8, height: 12), cornerRadius: 2).fill()
        }
    }
}
