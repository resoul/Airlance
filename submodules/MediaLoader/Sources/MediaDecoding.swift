import AVFoundation
import ImageIO
import MapKit
import UIKit

public enum VideoFrames {
    public static func first(of url: URL, maxSize: CGSize) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        guard let frame = try? await generator.image(at: .zero) else {
            return nil
        }

        return UIImage(cgImage: frame.image)
    }
}

public enum ImageDecoder {
    public static func image(at url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: image)
    }
}

enum MapSnapshots {
    private static let span: CLLocationDistance = 900

    static func snapshot(
        latitude: Double,
        longitude: Double,
        isDark: Bool,
        size: CGSize,
        scale: CGFloat
    ) async -> UIImage? {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: center, latitudinalMeters: span, longitudinalMeters: span)
        options.size = size
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(displayScale: scale),
            UITraitCollection(userInterfaceStyle: isDark ? .dark : .light),
        ])

        return try? await MKMapSnapshotter(options: options).start().image
    }
}
