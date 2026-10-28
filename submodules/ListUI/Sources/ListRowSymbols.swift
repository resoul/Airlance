import UIKit

public enum ListRowSymbols {
    private static let cache = SymbolCache()

    public static func image(
        _ name: String,
        size: CGFloat,
        color: UIColor,
        weight: UIImage.SymbolWeight = .regular
    ) -> UIImage {
        let key = "\(name)|\(size)|\(weight.rawValue)|\(color.hashValue)" as NSString
        if let image = cache.images.object(forKey: key) {
            return image
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        let image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal) ?? UIImage()
        cache.images.setObject(image, forKey: key)

        return image
    }
}

private final class SymbolCache: @unchecked Sendable {
    let images = NSCache<NSString, UIImage>()
}
