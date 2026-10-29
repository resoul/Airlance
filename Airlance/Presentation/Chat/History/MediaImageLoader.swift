import AVFoundation
import UIKit

struct MediaCorners: Sendable, Hashable {
    static let zero = MediaCorners(topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0)

    var topLeft: CGFloat
    var topRight: CGFloat
    var bottomLeft: CGFloat
    var bottomRight: CGFloat
}

struct MediaImageRequest: Sendable, Hashable {
    let source: String
    let size: CGSize
    let scale: CGFloat
    let corners: MediaCorners

    var key: String {
        "\(source)|\(Int(size.width))x\(Int(size.height))@\(scale)|\(corners.hashValue)"
    }
}

@MainActor
final class MediaImageLoader {
    static let shared = MediaImageLoader()

    @MainActor
    private final class Waiter {
        var isActive = true
    }

    @MainActor
    private final class Flight {
        let task: Task<UIImage?, Never>
        var waiters = 0

        init(task: Task<UIImage?, Never>) {
            self.task = task
        }
    }

    private let cache = NSCache<NSString, UIImage>()
    private var flights: [String: Flight] = [:]

    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func cached(_ request: MediaImageRequest) -> UIImage? {
        cache.object(forKey: request.key as NSString)
    }

    func image(for request: MediaImageRequest) async -> UIImage? {
        let key = request.key
        if let image = cache.object(forKey: key as NSString) {
            return image
        }

        let flight = flights[key] ?? start(request, key: key)
        let waiter = Waiter()
        flight.waiters += 1
        let image = await withTaskCancellationHandler {
            await flight.task.value
        } onCancel: {
            Task { @MainActor in
                self.leave(key, flight: flight, waiter: waiter)
            }
        }
        leave(key, flight: flight, waiter: waiter)

        return Task.isCancelled ? nil : image
    }

    private func start(_ request: MediaImageRequest, key: String) -> Flight {
        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard !Task.isCancelled else {
                return nil
            }

            return await MediaRenderer.render(request)
        }
        let flight = Flight(task: task)
        flights[key] = flight
        Task { [weak self] in
            guard let image = await task.value, let self else {
                return
            }

            self.store(image, for: request)
        }

        return flight
    }

    private func store(_ image: UIImage, for request: MediaImageRequest) {
        let cost = Int(request.size.width * request.size.height * request.scale * request.scale * 4)
        cache.setObject(image, forKey: request.key as NSString, cost: cost)
    }

    private func leave(_ key: String, flight: Flight, waiter: Waiter) {
        guard waiter.isActive else {
            return
        }

        waiter.isActive = false
        flight.waiters -= 1
        guard flight.waiters <= 0, flights[key] === flight else {
            return
        }

        flights[key] = nil
        if cache.object(forKey: key as NSString) == nil {
            flight.task.cancel()
        }
    }
}

enum MediaRenderer {
    static func render(_ request: MediaImageRequest) async -> UIImage? {
        let size = request.size
        guard size.width > 0, size.height > 0 else {
            return nil
        }

        let pixels = CGSize(width: ceil(size.width * request.scale), height: ceil(size.height * request.scale))
        let art: UIImage
        if let url = VideoFrames.url(for: request.source) {
            let side = max(pixels.width, pixels.height)
            guard let frame = await VideoFrames.first(of: url, maxSize: CGSize(width: side, height: side)) else {
                return nil
            }

            art = frame
        } else if MapSnapshots.isMap(request.source) {
            guard let map = await MapSnapshots.snapshot(request.source, size: size, scale: request.scale) else {
                return nil
            }

            art = map
        } else {
            art = StoryArt.render(seed: seed(request.source), size: pixels)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = request.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            path(CGRect(origin: .zero, size: size), corners: request.corners).addClip()
            art.draw(in: aspectFill(art.size, in: CGRect(origin: .zero, size: size)))
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

    private static func seed(_ source: String) -> Int {
        Int(source.split(separator: ":").last ?? "") ?? abs(source.hashValue)
    }

    static func path(_ rect: CGRect, corners: MediaCorners) -> UIBezierPath {
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

enum VideoFrames {
    private static let prefix = "bundle-video:"

    static func url(for source: String) -> URL? {
        guard source.hasPrefix(prefix) else {
            return nil
        }

        return Bundle.main.url(forResource: String(source.dropFirst(prefix.count)), withExtension: "mp4")
    }

    static func first(of url: URL, maxSize: CGSize) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        guard let frame = try? await generator.image(at: .zero) else {
            return nil
        }

        return UIImage(cgImage: frame.image)
    }
}
