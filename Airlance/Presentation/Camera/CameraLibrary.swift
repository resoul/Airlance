import AVFoundation
import CameraUI
import Photos
import UIKit

@MainActor
final class CameraLibrary: CameraGallery {
    private static let maxSide: CGFloat = 2048

    var onChange: (@MainActor () -> Void)?

    private let permissions: PermissionFlow
    private var library: AttachLibrary?

    init(permissions: PermissionFlow) {
        self.permissions = permissions
        attachIfAuthorized()
    }

    var isAuthorized: Bool {
        permissions.isAuthorized(.attachMedia)
    }

    var count: Int {
        library?.count ?? 0
    }

    func authorize(from presenter: UIViewController) async -> Bool {
        let granted = await permissions.authorize(.attachMedia, from: presenter)
        attachIfAuthorized()

        return granted
    }

    func identifier(at index: Int) -> String {
        library?.identifier(at: index) ?? ""
    }

    func duration(at index: Int) -> TimeInterval? {
        library?.duration(at: index)
    }

    func thumbnail(at index: Int, side: CGFloat, completion: @escaping @MainActor (UIImage?) -> Void) {
        guard let library, index < library.count else {
            completion(nil)

            return
        }

        library.thumbnail(at: index, pixelSide: side, completion: completion)
    }

    func load(at index: Int) async -> CameraCapture? {
        guard let library, index < library.count else {
            return nil
        }

        let asset = library.asset(at: index)
        if asset.mediaType == .video {
            return await Self.video(asset).map(CameraCapture.video)
        }

        return await Self.image(asset).map(CameraCapture.photo)
    }

    private func attachIfAuthorized() {
        guard library == nil, isAuthorized else {
            return
        }

        let library = AttachLibrary()
        library.onChange = { [weak self] in
            self?.onChange?()
        }
        self.library = library
        onChange?()
    }

    private static func image(_ asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        let scale = min(1, maxSide / CGFloat(max(asset.pixelWidth, asset.pixelHeight, 1)))
        let target = CGSize(width: CGFloat(asset.pixelWidth) * scale, height: CGFloat(asset.pixelHeight) * scale)
        let result: SendableImage = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: SendableImage(image: image))
            }
        }

        return result.image
    }

    private static func video(_ asset: PHAsset) async -> URL? {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        let source: URL? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: (avAsset as? AVURLAsset)?.url)
            }
        }
        guard let source else {
            return nil
        }

        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(source.pathExtension.isEmpty ? "mov" : source.pathExtension)
        do {
            try FileManager.default.copyItem(at: source, to: copy)
        } catch {
            return nil
        }

        return copy
    }
}
