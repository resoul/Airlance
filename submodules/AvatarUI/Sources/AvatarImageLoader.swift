import ImageIO
import UIKit

final class AvatarImageLoader: Sendable {
    static let shared = AvatarImageLoader()

    private let cache = AvatarImageCache()

    func cached(_ key: String) -> UIImage? {
        cache.image(for: key)
    }

    func placeholder(for descriptor: AvatarDescriptor, pixelSize: Int, rounded: Bool) async -> UIImage {
        let key = Self.placeholderKey(descriptor, pixelSize: pixelSize, rounded: rounded)
        if let cached = cache.image(for: key) {
            return cached
        }

        let initials = descriptor.initials
        let colors = descriptor.colors
        let image = await Task.detached(priority: .userInitiated) {
            AvatarRenderer.placeholder(initials: initials, colors: colors, pixelSize: pixelSize, rounded: rounded)
        }.value
        cache.store(image, for: key)

        return image
    }

    func photo(_ image: AvatarImage, pixelSize: Int, rounded: Bool) async -> UIImage? {
        let key = Self.photoKey(image, pixelSize: pixelSize, rounded: rounded)
        if let cached = cache.image(for: key) {
            return cached
        }

        let rendered = await Task.detached(priority: .userInitiated) {
            await image.load().flatMap { data in
                Self.decode(data, pixelSize: pixelSize).map { decoded in
                    AvatarRenderer.photo(decoded, pixelSize: pixelSize, rounded: rounded)
                }
            }
        }.value
        if let rendered {
            cache.store(rendered, for: key)
        }

        return rendered
    }

    static func placeholderKey(_ descriptor: AvatarDescriptor, pixelSize: Int, rounded: Bool) -> String {
        "initials|\(descriptor.id)|\(descriptor.initials)|\(pixelSize)|\(rounded ? "circle" : "square")"
    }

    static func photoKey(_ image: AvatarImage, pixelSize: Int, rounded: Bool) -> String {
        "photo|\(image.key)|\(pixelSize)|\(rounded ? "circle" : "square")"
    }

    private static func decode(_ data: Data, pixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

final class AvatarImageCache: @unchecked Sendable {
    private let images = NSCache<NSString, UIImage>()

    init() {
        images.totalCostLimit = 48 * 1024 * 1024
        images.countLimit = 600
    }

    func image(for key: String) -> UIImage? {
        images.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, for key: String) {
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        images.setObject(image, forKey: key as NSString, cost: cost)
    }
}
