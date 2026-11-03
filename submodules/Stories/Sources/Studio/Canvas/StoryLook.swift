import UIKit

enum StoryLook {
    static let fontScale: CGFloat = 0.082

    static func font(_ font: StoryFont, size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .heavy)
        switch font {
        case .bold:
            return base
        case .rounded:
            return base.fontDescriptor.withDesign(.rounded).map { descriptor in
                UIFont(descriptor: descriptor, size: size)
            } ?? base
        case .serif:
            let bold = UIFont.systemFont(ofSize: size, weight: .bold)

            return bold.fontDescriptor.withDesign(.serif).map { descriptor in
                UIFont(descriptor: descriptor, size: size)
            } ?? bold
        case .mono:
            return .monospacedSystemFont(ofSize: size * 0.9, weight: .bold)
        case .hand:
            return UIFont(name: "Noteworthy-Bold", size: size * 1.05) ?? base
        }
    }

    static func contrast(for color: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue

        return luminance > 0.6 ? .black : .white
    }

    @MainActor
    static func apply(_ text: StoryText, to label: UILabel, width: CGFloat) {
        let size = max(12, width * fontScale)
        let color = text.color.uiColor
        let font = font(text.font, size: size)
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        label.backgroundColor = .clear
        label.layer.cornerRadius = size * 0.28
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = false
        label.shadowColor = nil
        switch text.style {
        case .shadow:
            attributes[.foregroundColor] = color
            label.shadowColor = (color == .black ? UIColor.white : UIColor.black).withAlphaComponent(0.4)
            label.shadowOffset = CGSize(width: 0, height: 1)
        case .filled:
            attributes[.foregroundColor] = contrast(for: color)
            label.backgroundColor = color
            label.clipsToBounds = true
        case .semi:
            attributes[.foregroundColor] = color
            label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            label.clipsToBounds = true
        case .outline:
            attributes[.foregroundColor] = contrast(for: color)
            attributes[.strokeColor] = color
            attributes[.strokeWidth] = -5
        }
        label.attributedText = NSAttributedString(string: text.text, attributes: attributes)
        let fitted = label.sizeThatFits(CGSize(width: width - 48, height: .greatestFiniteMagnitude))
        let padding = text.style == .filled || text.style == .semi ? size * 0.5 : 16
        label.bounds = CGRect(origin: .zero, size: CGSize(width: fitted.width + padding, height: fitted.height + 8))
    }

    static func apply(_ stroke: StoryStroke, to layer: CAShapeLayer, path: UIBezierPath, width: CGFloat) {
        let color = stroke.color.uiColor
        let line = stroke.width * width
        layer.strokeColor = color.cgColor
        layer.lineWidth = line
        layer.opacity = 1
        layer.shadowOpacity = 0
        switch stroke.brush {
        case .pen, .eraser:
            layer.path = path.cgPath
        case .marker:
            layer.lineWidth = line * 2.6
            layer.opacity = 0.5
            layer.lineCap = .butt
            layer.path = path.cgPath
        case .neon:
            layer.strokeColor = UIColor.white.cgColor
            layer.lineWidth = line * 0.85
            layer.shadowColor = color.cgColor
            layer.shadowRadius = line * 1.4
            layer.shadowOpacity = 1
            layer.shadowOffset = .zero
            layer.path = path.cgPath
        case .arrow:
            layer.path = arrow(path, points: path.cgPath.points, length: line * 3.4).cgPath
        }
    }

    private static func arrow(_ path: UIBezierPath, points: [CGPoint], length: CGFloat) -> UIBezierPath {
        guard let tip = points.last else {
            return path
        }

        let base = points.reversed().first { point in
            hypot(point.x - tip.x, point.y - tip.y) > length
        } ?? points.first ?? tip
        let angle = atan2(tip.y - base.y, tip.x - base.x)
        let result = UIBezierPath(cgPath: path.cgPath)
        for side in [CGFloat.pi * 0.8, -CGFloat.pi * 0.8] {
            result.move(to: tip)
            result.addLine(to: CGPoint(x: tip.x + cos(angle + side) * length, y: tip.y + sin(angle + side) * length))
        }

        return result
    }
}

extension CGPath {
    fileprivate var points: [CGPoint] {
        var result: [CGPoint] = []
        applyWithBlock { element in
            let kind = element.pointee.type
            if kind == .moveToPoint || kind == .addLineToPoint {
                result.append(element.pointee.points[0])
            }
        }

        return result
    }
}
