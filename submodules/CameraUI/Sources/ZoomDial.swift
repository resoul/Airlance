import UIKit

final class ZoomDial: UIView {
    static let height: CGFloat = 130

    private static let sweep: CGFloat = .pi * 0.55
    private static let tickCount = 64

    private let backdrop = CAShapeLayer()
    private let wheel = CALayer()
    private let ticks = CAShapeLayer()
    private let majorTicks = CAShapeLayer()
    private let marker = CAShapeLayer()
    private let valueLabel = UILabel()
    private var range: ClosedRange<CGFloat> = 1...10
    private var stops: [CGFloat] = []
    private var labelLayers: [CATextLayer] = []

    private var radius: CGFloat {
        bounds.width * 0.85
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backdrop.fillColor = UIColor.black.withAlphaComponent(0.45).cgColor
        ticks.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        ticks.lineWidth = 1
        majorTicks.strokeColor = UIColor.white.cgColor
        majorTicks.lineWidth = 2
        majorTicks.lineCap = .round
        marker.fillColor = UIColor.systemYellow.cgColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        valueLabel.textColor = .systemYellow
        valueLabel.textAlignment = .center
        layer.addSublayer(backdrop)
        wheel.addSublayer(ticks)
        wheel.addSublayer(majorTicks)
        layer.addSublayer(wheel)
        layer.addSublayer(marker)
        addSubview(valueLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(range: ClosedRange<CGFloat>, stops: [CGFloat]) {
        self.range = range
        self.stops = stops
        setNeedsLayout()
    }

    func update(zoom: CGFloat) {
        valueLabel.text = ZoomLensBar.format(zoom) + "×"
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        wheel.setAffineTransform(CGAffineTransform(rotationAngle: -angle(of: zoom)))
        CATransaction.commit()
    }

    func zoom(from start: CGFloat, drag: CGFloat) -> CGFloat {
        let target = angle(of: start) - drag / radius
        let span = log(range.upperBound / range.lowerBound)
        let zoom = range.lowerBound * exp(target / Self.sweep * span)

        return min(max(zoom, range.lowerBound), range.upperBound)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: 34 + radius)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdrop.frame = bounds
        let reach = radius + 34
        backdrop.path = UIBezierPath(
            ovalIn: CGRect(x: center.x - reach, y: center.y - reach, width: reach * 2, height: reach * 2)
        ).cgPath
        wheel.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        wheel.position = center
        ticks.frame = wheel.bounds
        majorTicks.frame = wheel.bounds
        drawTicks()
        marker.frame = bounds
        marker.path = UIBezierPath(ovalIn: CGRect(x: bounds.midX - 3, y: 24, width: 6, height: 6)).cgPath
        CATransaction.commit()
        valueLabel.frame = CGRect(x: bounds.midX - 40, y: 0, width: 80, height: 22)
    }

    private func angle(of zoom: CGFloat) -> CGFloat {
        let span = log(range.upperBound / range.lowerBound)
        guard span > 0 else {
            return 0
        }

        return log(max(zoom, range.lowerBound) / range.lowerBound) / span * Self.sweep
    }

    private func drawTicks() {
        let center = CGPoint(x: radius, y: radius)
        let minor = UIBezierPath()
        for index in 0...Self.tickCount {
            let angle = Self.sweep * CGFloat(index) / CGFloat(Self.tickCount)
            addTick(to: minor, center: center, angle: angle, length: 8)
        }
        ticks.path = minor.cgPath
        let major = UIBezierPath()
        for label in labelLayers {
            label.removeFromSuperlayer()
        }
        labelLayers = stops.map { stop in
            let angle = angle(of: stop)
            addTick(to: major, center: center, angle: angle, length: 14)

            return label(ZoomLensBar.format(stop), center: center, angle: angle)
        }
        majorTicks.path = major.cgPath
    }

    private func addTick(to path: UIBezierPath, center: CGPoint, angle: CGFloat, length: CGFloat) {
        let direction = CGPoint(x: sin(angle), y: -cos(angle))
        path.move(to: CGPoint(x: center.x + direction.x * radius, y: center.y + direction.y * radius))
        path.addLine(to: CGPoint(
            x: center.x + direction.x * (radius - length),
            y: center.y + direction.y * (radius - length)
        ))
    }

    private func label(_ text: String, center: CGPoint, angle: CGFloat) -> CATextLayer {
        let label = CATextLayer()
        label.string = text
        label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        label.fontSize = 13
        label.alignmentMode = .center
        label.foregroundColor = UIColor.white.cgColor
        label.contentsScale = traitCollection.displayScale
        label.bounds = CGRect(x: 0, y: 0, width: 40, height: 18)
        let distance = radius - 28
        label.position = CGPoint(x: center.x + sin(angle) * distance, y: center.y - cos(angle) * distance)
        label.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        wheel.addSublayer(label)

        return label
    }
}
