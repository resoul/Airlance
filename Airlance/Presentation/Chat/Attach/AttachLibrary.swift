import Photos
import UIKit

@MainActor
final class AttachLibrary: NSObject, PHPhotoLibraryChangeObserver {
    var onChange: (@MainActor () -> Void)?

    private var assets: PHFetchResult<PHAsset>
    private let images = PHCachingImageManager()

    override init() {
        assets = Self.fetch()
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    var count: Int {
        assets.count
    }

    func asset(at index: Int) -> PHAsset {
        assets.object(at: index)
    }

    func identifier(at index: Int) -> String {
        assets.object(at: index).localIdentifier
    }

    func duration(at index: Int) -> TimeInterval? {
        let asset = assets.object(at: index)

        return asset.mediaType == .video ? asset.duration : nil
    }

    @discardableResult
    func thumbnail(
        at index: Int,
        pixelSide: CGFloat,
        completion: @escaping @MainActor (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let handler: @Sendable (UIImage?, [AnyHashable: Any]?) -> Void = { image, _ in
            let result = SendableImage(image: image)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    completion(result.image)
                }
            }
        }

        return images.requestImage(
            for: assets.object(at: index),
            targetSize: CGSize(width: pixelSide, height: pixelSide),
            contentMode: .aspectFill,
            options: options,
            resultHandler: handler
        )
    }

    func cancel(_ request: PHImageRequestID) {
        images.cancelImageRequest(request)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.assets = Self.fetch()
            self.onChange?()
        }
    }

    private static func fetch() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType = %d OR mediaType = %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        return PHAsset.fetchAssets(with: options)
    }
}

struct SendableImage: @unchecked Sendable {
    let image: UIImage?
}
