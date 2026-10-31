import MediaStore
import UIKit

public struct MediaCorners: Sendable, Hashable {
    public static let zero = MediaCorners(topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0)

    public var topLeft: CGFloat
    public var topRight: CGFloat
    public var bottomLeft: CGFloat
    public var bottomRight: CGFloat

    public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public static func uniform(_ radius: CGFloat) -> MediaCorners {
        MediaCorners(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius)
    }
}

public struct MediaImageRequest: Sendable, Hashable {
    public let source: MediaSource
    public let size: CGSize
    public let scale: CGFloat
    public let corners: MediaCorners

    public init(source: MediaSource, size: CGSize, scale: CGFloat, corners: MediaCorners) {
        self.source = source
        self.size = size
        self.scale = scale
        self.corners = corners
    }

    var key: String {
        let corners = "\(corners.topLeft),\(corners.topRight),\(corners.bottomLeft),\(corners.bottomRight)"

        return "\(source.cacheKey)|\(Int(size.width))x\(Int(size.height))@\(scale)|\(corners)"
    }
}

@MainActor
public final class MediaImageLoader {
    public static let shared = MediaImageLoader()

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

    public func cached(_ request: MediaImageRequest) -> UIImage? {
        cache.object(forKey: request.key as NSString)
    }

    public func image(for request: MediaImageRequest) async -> UIImage? {
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
