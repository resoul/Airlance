import ChatHistory
import UIKit

enum MessageChecks {
    static func image(_ delivery: DeliveryState, color: UIColor, failed: UIColor) -> UIImage? {
        switch delivery {
        case .sending:
            symbol("clock", color: color)
        case .sent, .delivered:
            checks(count: 1, color: color)
        case .read:
            checks(count: 2, color: color)
        case .failed:
            symbol("exclamationmark.circle.fill", color: failed)
        }
    }

    private static func symbol(_ name: String, color: UIColor) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)

        return UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }

    private static func checks(count: Int, color: UIColor) -> UIImage {
        let size = CGSize(width: count == 1 ? 11 : 16, height: 10)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            color.setStroke()
            for index in 0..<count {
                let x = CGFloat(index) * 5
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x + 1, y: 5.5))
                path.addLine(to: CGPoint(x: x + 4, y: 8.5))
                path.addLine(to: CGPoint(x: x + 10, y: 1.5))
                path.lineWidth = 1.4
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
        }
    }
}
