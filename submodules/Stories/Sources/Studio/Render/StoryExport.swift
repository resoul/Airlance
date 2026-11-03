import AVFoundation
import Subtitles
import UIKit

public struct StoryRenderOptions: Sendable {
    public var adjustments = StoryAdjustments()
    public var transform = StoryMediaTransform()
    public var trim: StoryTrim?
    public var sound = StorySound()

    public init() {
    }

    init(_ draft: StoryDraft) {
        adjustments = draft.adjustments
        transform = draft.mediaTransform
        trim = draft.trim
        sound = draft.sound
    }
}

@MainActor
public enum StoryExport {
    public static let width: CGFloat = 1080

    public static func photo(
        _ image: UIImage,
        overlay: UIImage?,
        aspect: CGSize,
        options: StoryRenderOptions = StoryRenderOptions(),
        makeURL: @MainActor (String) -> URL
    ) -> URL? {
        let size = renderSize(aspect)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let source = StoryImageFilter.render(image, adjustments: options.adjustments)
        let transform = options.transform
        let result = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let canvas = context.cgContext
            UIColor.black.setFill()
            canvas.fill(CGRect(origin: .zero, size: size))
            canvas.saveGState()
            canvas.translateBy(
                x: size.width / 2 + transform.offset.x * size.width,
                y: size.height / 2 + transform.offset.y * size.height
            )
            canvas.rotate(by: transform.rotation)
            canvas.scaleBy(x: transform.scale, y: transform.scale)
            let fill = max(size.width / source.size.width, size.height / source.size.height)
            let drawn = CGSize(width: source.size.width * fill, height: source.size.height * fill)
            source.draw(in: CGRect(x: -drawn.width / 2, y: -drawn.height / 2, width: drawn.width, height: drawn.height))
            canvas.restoreGState()
            overlay?.draw(in: CGRect(origin: .zero, size: size))
        }
        let target = makeURL("jpg")
        guard let data = result.jpegData(compressionQuality: 0.9), (try? data.write(to: target)) != nil else {
            return nil
        }

        return target
    }

    public static func video(
        _ url: URL,
        overlay: UIImage?,
        subtitles: Subtitles?,
        aspect: CGSize,
        options: StoryRenderOptions = StoryRenderOptions(),
        keepsSource: Bool = true,
        makeURL: @MainActor (String) -> URL
    ) async -> URL? {
        let cgImage = overlay?.cgImage
        let source = url
        var url = url
        var subtitles = subtitles
        if !options.adjustments.isIdentity || options.trim != nil {
            guard let prepared = await prepass(url, options: options, makeURL: makeURL) else {
                return nil
            }

            if !keepsSource {
                try? FileManager.default.removeItem(at: url)
            }
            url = prepared
            subtitles = options.trim.flatMap { trim in
                subtitles?.shifted(by: trim.start, duration: trim.duration)
            } ?? subtitles
        }
        guard cgImage != nil || subtitles != nil || !options.transform.isIdentity || !options.sound.isIdentity else {
            return url
        }

        return await compose(
            url,
            overlay: cgImage,
            subtitles: subtitles,
            size: renderSize(aspect),
            options: options,
            removesSource: url != source || !keepsSource,
            makeURL: makeURL
        )
    }

    private static func compose(
        _ url: URL,
        overlay cgImage: CGImage?,
        subtitles: Subtitles?,
        size: CGSize,
        options: StoryRenderOptions,
        removesSource: Bool,
        makeURL: @MainActor (String) -> URL
    ) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let duration = try? await asset.load(.duration),
              let natural = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else {
            return url
        }

        let range = CMTimeRange(start: .zero, duration: duration)
        let composition = AVMutableComposition()
        let trackID = kCMPersistentTrackID_Invalid
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: trackID),
              (try? videoTrack.insertTimeRange(range, of: track, at: .zero)) != nil else {
            return url
        }

        let original = await originalAudio(of: asset, range: range, into: composition)
        let audioMix = await StoryAudioMix.make(options.sound, in: composition, original: original, duration: duration)
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let placed = fill(natural: natural, transform: transform, into: size)
            .concatenating(self.media(options.transform, in: size))
        layer.setTransform(placed, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        instruction.layerInstructions = [layer]
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = animationTool(overlay: cgImage, subtitles: subtitles, size: size)
        let target = makeURL("mp4")
        guard await export(composition, videoComposition: videoComposition, audioMix: audioMix, to: target) else {
            return url
        }

        if removesSource {
            try? FileManager.default.removeItem(at: url)
        }

        return target
    }

    private static func originalAudio(
        of asset: AVURLAsset,
        range: CMTimeRange,
        into composition: AVMutableComposition
    ) async -> AVMutableCompositionTrack? {
        let trackID = kCMPersistentTrackID_Invalid
        guard let audio = try? await asset.loadTracks(withMediaType: .audio).first,
              let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: trackID),
              (try? track.insertTimeRange(range, of: audio, at: .zero)) != nil else {
            return nil
        }

        return track
    }

    private static func prepass(
        _ url: URL,
        options: StoryRenderOptions,
        makeURL: @MainActor (String) -> URL
    ) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            return nil
        }

        session.videoComposition = await StoryImageFilter.videoComposition(for: asset, adjustments: options.adjustments)
        if let trim = options.trim {
            session.timeRange = CMTimeRange(
                start: CMTime(seconds: trim.start, preferredTimescale: 600),
                end: CMTime(seconds: trim.end, preferredTimescale: 600)
            )
        }
        let target = makeURL("mp4")
        session.outputURL = target
        session.outputFileType = .mp4
        let box = StoryExportBox(session: session)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            box.session.exportAsynchronously {
                continuation.resume()
            }
        }

        return FileManager.default.fileExists(atPath: target.path) ? target : nil
    }

    private static func media(_ transform: StoryMediaTransform, in size: CGSize) -> CGAffineTransform {
        guard !transform.isIdentity else {
            return .identity
        }

        return CGAffineTransform(translationX: -size.width / 2, y: -size.height / 2)
            .concatenating(CGAffineTransform(scaleX: transform.scale, y: transform.scale))
            .concatenating(CGAffineTransform(rotationAngle: transform.rotation))
            .concatenating(CGAffineTransform(
                translationX: size.width / 2 + transform.offset.x * size.width,
                y: size.height / 2 + transform.offset.y * size.height
            ))
    }

    private static func renderSize(_ aspect: CGSize) -> CGSize {
        let ratio = aspect.width > 0 ? aspect.height / aspect.width : 16 / 9
        let height = (width * ratio / 2).rounded() * 2

        return CGSize(width: width, height: height)
    }

    private static func fill(natural: CGSize, transform: CGAffineTransform, into size: CGSize) -> CGAffineTransform {
        let box = CGRect(origin: .zero, size: natural).applying(transform)
        let upright = transform.concatenating(CGAffineTransform(translationX: -box.minX, y: -box.minY))
        let scale = max(size.width / box.width, size.height / box.height)
        let offset = CGPoint(x: (size.width - box.width * scale) / 2, y: (size.height - box.height * scale) / 2)

        return upright
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offset.x, y: offset.y))
    }

    private static func animationTool(
        overlay: CGImage?,
        subtitles: Subtitles?,
        size: CGSize
    ) -> AVVideoCompositionCoreAnimationTool {
        let frame = CGRect(origin: .zero, size: size)
        let parent = CALayer()
        let video = CALayer()
        let image = CALayer()
        for layer in [parent, video, image] {
            layer.frame = frame
        }
        image.contents = overlay
        image.contentsGravity = .resize
        parent.addSublayer(video)
        parent.addSublayer(image)
        if let subtitles {
            parent.addSublayer(SubtitleLayers.make(subtitles, size: size))
        }

        return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: parent)
    }

    private static func export(
        _ composition: AVComposition,
        videoComposition: AVVideoComposition,
        audioMix: AVAudioMix?,
        to target: URL
    ) async -> Bool {
        let preset = AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: composition, presetName: preset) else {
            return false
        }

        session.videoComposition = videoComposition
        session.audioMix = audioMix
        session.outputURL = target
        session.outputFileType = .mp4
        let box = StoryExportBox(session: session)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            box.session.exportAsynchronously {
                continuation.resume()
            }
        }

        return FileManager.default.fileExists(atPath: target.path)
    }
}

private struct StoryExportBox: @unchecked Sendable {
    let session: AVAssetExportSession
}

extension Subtitles {
    func shifted(by offset: TimeInterval, duration: TimeInterval) -> Subtitles {
        var shifted = self
        shifted.phrases = phrases.compactMap { phrase in
            var phrase = phrase
            phrase.words = phrase.words.compactMap { word in
                let start = word.start - offset
                let end = word.end - offset
                guard end > 0, start < duration else {
                    return nil
                }

                return SubtitleWord(text: word.text, start: max(0, start), end: min(duration, end))
            }

            return phrase.words.isEmpty ? nil : phrase
        }

        return shifted
    }
}
