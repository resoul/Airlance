import AVFoundation
import ChatHistory
import MediaStore
import Photos
import UIKit

@MainActor
enum AttachExport {
    private static let maxSide: CGFloat = 2560

    static func photos(_ assets: [PHAsset], store: MediaStore) async -> [MessagePhoto] {
        var photos: [MessagePhoto] = []
        for asset in assets {
            let photo = asset.mediaType == .video ? await video(asset, store: store) : await image(asset, store: store)
            if let photo {
                photos.append(photo)
            }
        }

        return photos
    }

    static func photo(from image: UIImage, store: MediaStore) -> MessagePhoto? {
        guard let data = image.jpegData(compressionQuality: 0.85),
              let media = store.store(data, kind: .image, extension: "jpg") else {
            return nil
        }

        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)

        return MessagePhoto(
            id: media.name,
            width: Int(pixels.width),
            height: Int(pixels.height),
            source: .local(media)
        )
    }

    static func video(at url: URL, store: MediaStore) async -> MessagePhoto? {
        guard let media = store.adopt(url, kind: .video) else {
            return nil
        }

        let asset = AVURLAsset(url: MediaStore.url(for: media))
        let duration = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
        let track = try? await asset.loadTracks(withMediaType: .video).first
        let natural = (try? await track?.load(.naturalSize)) ?? CGSize(width: 1280, height: 720)
        let transform = (try? await track?.load(.preferredTransform)) ?? .identity
        let size = natural.applying(transform)
        let source = MediaSource.local(media)

        return MessagePhoto(
            id: media.name,
            width: Int(abs(size.width)),
            height: Int(abs(size.height)),
            source: source,
            video: MessageVideo(source: source, duration: duration)
        )
    }

    private static func image(_ asset: PHAsset, store: MediaStore) async -> MessagePhoto? {
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

        return result.image.flatMap { image in
            photo(from: image, store: store)
        }
    }

    private static func video(_ asset: PHAsset, store: MediaStore) async -> MessagePhoto? {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        let url: URL? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: (avAsset as? AVURLAsset)?.url)
            }
        }
        guard let url else {
            return nil
        }

        return await video(at: url, store: store)
    }
}
