import UIKit

enum AvatarRenderer {
    static func placeholder(initials: String, colors: [UIColor], pixelSize: Int, rounded: Bool) -> UIImage {
        let side = CGFloat(pixelSize)
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)

        return renderer(side: side).image { context in
            let cg = context.cgContext
            if rounded {
                UIBezierPath(ovalIn: bounds).addClip()
            }

            let cgColors = colors.map(\.cgColor) as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: side / 2, y: 0),
                    end: CGPoint(x: side / 2, y: side),
                    options: []
                )
            }

            let font = UIFont.systemFont(ofSize: side * 0.4, weight: .semibold)
            let text = NSAttributedString(string: initials, attributes: [.font: font, .foregroundColor: UIColor.white])
            let size = text.size()
            text.draw(at: CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2))
        }
    }

    static func photo(_ image: CGImage, pixelSize: Int, rounded: Bool) -> UIImage {
        let side = CGFloat(pixelSize)
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = max(side / max(width, 1), side / max(height, 1))
        let drawSize = CGSize(width: width * scale, height: height * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)

        return renderer(side: side).image { _ in
            if rounded {
                UIBezierPath(ovalIn: bounds).addClip()
            }
            UIImage(cgImage: image).draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    private static func renderer(side: CGFloat) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
    }
}
