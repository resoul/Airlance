import UIKit

enum StoryCollage {
    static func render(_ layout: StoryCollageLayout, images: [UIImage], size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (cell, image) in zip(layout.cells, images) {
                let rect = CGRect(
                    x: (cell.minX * size.width).rounded(),
                    y: (cell.minY * size.height).rounded(),
                    width: (cell.width * size.width).rounded(),
                    height: (cell.height * size.height).rounded()
                )
                context.cgContext.saveGState()
                context.cgContext.clip(to: rect)
                fill(image, into: rect)
                context.cgContext.restoreGState()
            }
        }
    }

    static func icon(_ layout: StoryCollageLayout, side: CGFloat) -> UIImage {
        let size = CGSize(width: side * 0.62, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            for cell in layout.cells {
                let rect = CGRect(
                    x: cell.minX * size.width,
                    y: cell.minY * size.height,
                    width: cell.width * size.width,
                    height: cell.height * size.height
                ).insetBy(dx: 1, dy: 1)
                UIBezierPath(roundedRect: rect, cornerRadius: 2).fill()
            }
        }
    }

    static func crop(_ image: UIImage, to cell: CGRect, preview: CGSize) -> UIImage {
        let size = image.size
        let isSameOrientation = (size.width > size.height) == (preview.width > preview.height)
        guard isSameOrientation, size.width > 0, size.height > 0, preview.width > 0, preview.height > 0 else {
            return image
        }

        let scale = max(preview.width / size.width, preview.height / size.height)
        let offset = CGPoint(
            x: (size.width * scale - preview.width) / 2,
            y: (size.height * scale - preview.height) / 2
        )
        let rect = CGRect(
            x: (cell.minX * preview.width + offset.x) / scale,
            y: (cell.minY * preview.height + offset.y) / scale,
            width: cell.width * preview.width / scale,
            height: cell.height * preview.height / scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            image.draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
    }

    private static func fill(_ image: UIImage, into rect: CGRect) {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return
        }

        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        image.draw(in: CGRect(
            x: rect.midX - drawn.width / 2,
            y: rect.midY - drawn.height / 2,
            width: drawn.width,
            height: drawn.height
        ))
    }
}
