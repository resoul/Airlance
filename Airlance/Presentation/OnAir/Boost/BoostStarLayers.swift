import UIKit

@MainActor
final class BoostStarLayers {
    let container = CALayer()
    let glow = CAShapeLayer()
    let fill = CAGradientLayer()
    let mask = CAShapeLayer()
    let ring = CAShapeLayer()
    let track = CAShapeLayer()
    let sparks = CAEmitterLayer()

    init() {
        track.fillColor = UIColor.clear.cgColor
        track.lineWidth = 4
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 4
        ring.lineCap = .round
        ring.strokeEnd = 0
        glow.shadowOffset = .zero
        glow.lineJoin = .round
        glow.lineWidth = 6
        fill.type = .radial
        fill.startPoint = CGPoint(x: 0.5, y: 0.45)
        fill.endPoint = CGPoint(x: 1, y: 1)
        mask.lineJoin = .round
        mask.lineWidth = 6
        mask.strokeColor = UIColor.black.cgColor
        mask.fillColor = UIColor.black.cgColor
        fill.mask = mask
        container.addSublayer(glow)
        container.addSublayer(fill)
        sparks.emitterShape = .point
        sparks.renderMode = .additive
        sparks.birthRate = 0
        sparks.emitterCells = [Self.spark(color: .systemYellow), Self.spark(color: .systemOrange)]
    }

    func layout(in bounds: CGRect) {
        let side = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let ringRect = CGRect(x: center.x - side / 2 + 2, y: center.y - side / 2 + 2, width: side - 4, height: side - 4)
        let ringPath = UIBezierPath(
            arcCenter: center,
            radius: ringRect.width / 2,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        track.path = ringPath.cgPath
        ring.path = ringPath.cgPath
        container.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        container.position = center
        let star = Self.starPath(center: CGPoint(x: side / 2, y: side / 2 + side * 0.03), radius: side * 0.3).cgPath
        glow.path = star
        mask.path = star
        fill.frame = container.bounds
        sparks.emitterPosition = center
    }

    func apply(heat: CGFloat, base: UIColor) {
        let colors = Self.heatColors(heat)
        fill.colors = colors.map(\.cgColor)
        glow.fillColor = colors[1].cgColor
        glow.strokeColor = colors[1].cgColor
        glow.shadowColor = colors[1].cgColor
        glow.shadowRadius = 6 + 28 * heat
        glow.shadowOpacity = Float(0.45 + 0.55 * heat)
        ring.strokeColor = colors[1].cgColor
        track.strokeColor = base.withAlphaComponent(0.15).cgColor
    }

    func burst() {
        sparks.beginTime = CACurrentMediaTime()
        sparks.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.sparks.birthRate = 0
        }
    }

    private static func heatColors(_ heat: CGFloat) -> [UIColor] {
        let cold = [color(0.93, 0.45), color(0.72, 0.1)]
        let warm = [color(0.8, 0.3), color(0.42, 0.08)]
        let hot = [color(1, 0.95), color(0.55, 0.3)]
        guard heat > 0.6 else {
            return zip(cold, warm).map { lhs, rhs in
                mix(lhs, rhs, heat / 0.6)
            }
        }

        return zip(warm, hot).map { lhs, rhs in
            mix(lhs, rhs, (heat - 0.6) / 0.4)
        }
    }

    private static func color(_ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: 1, green: green, blue: blue, alpha: 1)
    }

    private static func mix(_ lhs: UIColor, _ rhs: UIColor, _ amount: CGFloat) -> UIColor {
        var left = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0), alpha: CGFloat(0))
        var right = left
        lhs.getRed(&left.red, green: &left.green, blue: &left.blue, alpha: &left.alpha)
        rhs.getRed(&right.red, green: &right.green, blue: &right.blue, alpha: &right.alpha)
        let amount = min(max(amount, 0), 1)

        return UIColor(
            red: left.red + (right.red - left.red) * amount,
            green: left.green + (right.green - left.green) * amount,
            blue: left.blue + (right.blue - left.blue) * amount,
            alpha: 1
        )
    }

    private static func starPath(center: CGPoint, radius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        for index in 0..<10 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 5
            let length = index.isMultiple(of: 2) ? radius : radius * 0.46
            let point = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()

        return path
    }

    private static func spark(color: UIColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 12, height: 12))
        }.cgImage
        cell.birthRate = 400
        cell.lifetime = 0.9
        cell.velocity = 320
        cell.velocityRange = 160
        cell.emissionRange = .pi * 2
        cell.scale = 0.5
        cell.scaleRange = 0.3
        cell.scaleSpeed = -0.5
        cell.alphaSpeed = -1.1
        cell.color = color.cgColor

        return cell
    }
}
