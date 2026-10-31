import MediaStore
import UIKit

public enum MediaRenderer {
    nonisolated(unsafe) public static var generatedArt: @Sendable (Int, CGSize) -> UIImage = { _, size in
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemGray4.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func render(_ request: MediaImageRequest) async -> UIImage? {
        let size = request.size
        guard size.width > 0, size.height > 0, let art = await art(for: request) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = request.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            path(CGRect(origin: .zero, size: size), corners: request.corners).addClip()
            art.draw(in: aspectFill(art.size, in: CGRect(origin: .zero, size: size)))
        }
    }

    private static func art(for request: MediaImageRequest) async -> UIImage? {
        let pixels = CGSize(
            width: ceil(request.size.width * request.scale),
            height: ceil(request.size.height * request.scale)
        )
        let side = max(pixels.width, pixels.height)
        switch request.source {
        case .generated(let seed):
            return generatedArt(seed, pixels)
        case .map(let latitude, let longitude, let isDark):
            return await MapSnapshots.snapshot(
                latitude: latitude,
                longitude: longitude,
                isDark: isDark,
                size: request.size,
                scale: request.scale
            )
        case .bundle, .local:
            guard let url = request.source.url else {
                return nil
            }

            if request.source.isVideo {
                return await VideoFrames.first(of: url, maxSize: CGSize(width: side, height: side))
            }

            return ImageDecoder.image(at: url, maxPixel: side)
        }
    }

    private static func aspectFill(_ size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else {
            return rect
        }

        let scale = max(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)

        return CGRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    public static func path(_ rect: CGRect, corners: MediaCorners) -> UIBezierPath {
        let path = UIBezierPath()
        let minX = rect.minX
        let minY = rect.minY
        let maxX = rect.maxX
        let maxY = rect.maxY
        path.move(to: CGPoint(x: minX + corners.topLeft, y: minY))
        path.addLine(to: CGPoint(x: maxX - corners.topRight, y: minY))
        path.addQuadCurve(to: CGPoint(x: maxX, y: minY + corners.topRight), controlPoint: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: maxY - corners.bottomRight))
        path.addQuadCurve(to: CGPoint(x: maxX - corners.bottomRight, y: maxY), controlPoint: CGPoint(x: maxX, y: maxY))
        path.addLine(to: CGPoint(x: minX + corners.bottomLeft, y: maxY))
        path.addQuadCurve(to: CGPoint(x: minX, y: maxY - corners.bottomLeft), controlPoint: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: minX, y: minY + corners.topLeft))
        path.addQuadCurve(to: CGPoint(x: minX + corners.topLeft, y: minY), controlPoint: CGPoint(x: minX, y: minY))
        path.close()

        return path
    }
}
