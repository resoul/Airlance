import AvatarUI
import AVFoundation
import FFmpegBinding
import Foundation
import MediaStore
import MozjpegBinding
import UIKit

struct ProcessedAvatarVideo: Sendable {
    let video: LocalMedia
    let poster: LocalMedia
}

enum AvatarVideoProcessor {
    private static let side: CGFloat = 720
    private static let posterQuality: Int32 = 80

    static func process(
        _ source: URL,
        range: AvatarTrimRange,
        framing: CGSize?,
        store: MediaStore
    ) async -> ProcessedAvatarVideo? {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer {
            try? FileManager.default.removeItem(at: scratch)
        }

        guard await encode(source, range: range, framing: framing, to: scratch),
              let poster = await poster(of: scratch, store: store) else {
            return nil
        }

        let target = store.reserve(.video, extension: "mp4")
        let duration = AvatarVideo.maximumDuration
        guard FFmpegCopyVideoTrack(scratch.path, target.url.path, duration) else {
            store.remove(poster)

            return nil
        }

        return ProcessedAvatarVideo(video: target.media, poster: poster)
    }

    private static func encode(
        _ source: URL,
        range trim: AvatarTrimRange,
        framing: CGSize?,
        to target: URL
    ) async -> Bool {
        let asset = AVURLAsset(url: source)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let natural = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform),
              let length = try? await asset.load(.duration),
              let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            return false
        }

        let whole = CMTimeRange(start: .zero, duration: length)
        let start = CMTime(seconds: trim.start, preferredTimescale: 600)
        let longest = min(trim.end - trim.start, AvatarVideo.maximumDuration)
        let shown = CGRect(origin: .zero, size: natural).applying(transform).size
        let fraction = AvatarFraming.fraction(content: shown, preview: framing)
        session.videoComposition = composition(
            track,
            natural: natural,
            transform: transform,
            range: whole,
            fraction: fraction
        )
        session.timeRange = CMTimeRange(start: start, duration: CMTime(seconds: longest, preferredTimescale: 600))
        session.outputURL = target
        session.outputFileType = .mp4
        let box = AvatarExportBox(session: session)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            box.session.exportAsynchronously {
                continuation.resume()
            }
        }

        return box.session.status == .completed
    }

    private static func composition(
        _ track: AVAssetTrack,
        natural: CGSize,
        transform: CGAffineTransform,
        range: CMTimeRange,
        fraction: CGFloat
    ) -> AVMutableVideoComposition {
        let shown = CGRect(origin: .zero, size: natural).applying(transform)
        let scale = side / (min(shown.width, shown.height) * fraction)
        let centered = transform
            .concatenating(CGAffineTransform(translationX: -shown.minX, y: -shown.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(
                translationX: (side - shown.width * scale) / 2,
                y: (side - shown.height * scale) / 2
            ))
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(centered, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        instruction.layerInstructions = [layer]
        let composition = AVMutableVideoComposition()
        composition.instructions = [instruction]
        composition.renderSize = CGSize(width: side, height: side)
        composition.frameDuration = CMTime(value: 1, timescale: 30)

        return composition
    }

    private static func poster(of video: URL, store: MediaStore) async -> LocalMedia? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .positiveInfinity
        let frame = await withCheckedContinuation { (continuation: CheckedContinuation<AvatarFrameBox?, Never>) in
            generator.generateCGImageAsynchronously(for: .zero) { image, _, _ in
                continuation.resume(returning: image.map(AvatarFrameBox.init))
            }
        }
        guard let frame, let jpeg = MozjpegEncode(frame.image, posterQuality) else {
            return nil
        }

        return store.store(jpeg, kind: .image, extension: "jpg")
    }
}

private struct AvatarExportBox: @unchecked Sendable {
    let session: AVAssetExportSession
}

private struct AvatarFrameBox: @unchecked Sendable {
    let image: CGImage
}
