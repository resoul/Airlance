import UIKit

enum StoryArt {
    private static let scenes: [(hues: (CGFloat, CGFloat), symbol: String)] = [
        ((0.58, 0.72), "🏔️"),
        ((0.02, 0.10), "🌅"),
        ((0.33, 0.45), "🌿"),
        ((0.78, 0.90), "🎧"),
        ((0.12, 0.55), "☕️"),
        ((0.95, 0.62), "🎉"),
    ]

    static func render(seed: Int, size: CGSize) -> UIImage {
        let scene = scenes[abs(seed) % scenes.count]
        let side = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: side, format: format).image { context in
            let colors = [
                UIColor(hue: scene.hues.0, saturation: 0.65, brightness: 0.85, alpha: 1).cgColor,
                UIColor(hue: scene.hues.1, saturation: 0.75, brightness: 0.45, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: side.width, y: side.height),
                    options: []
                )
            }

            let font = UIFont.systemFont(ofSize: side.width * 0.32)
            let text = NSAttributedString(string: scene.symbol, attributes: [.font: font])
            let textSize = text.size()
            text.draw(at: CGPoint(x: (side.width - textSize.width) / 2, y: (side.height - textSize.height) / 2))
        }
    }
}
