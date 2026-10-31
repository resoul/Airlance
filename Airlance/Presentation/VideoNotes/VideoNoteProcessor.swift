import AVFoundation
import MediaStore

enum VideoNoteProcessor {
    static func merge(_ segments: [URL], store: MediaStore) async -> URL? {
        guard segments.count > 1 else {
            return segments.first
        }

        let composition = AVMutableComposition()
        let trackID = kCMPersistentTrackID_Invalid
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: trackID) else {
            return segments.first
        }

        let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: trackID)
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: video)
        var cursor = CMTime.zero
        var renderSize = CGSize.zero
        for url in segments {
            let asset = AVURLAsset(url: url)
            guard let duration = try? await asset.load(.duration),
                  let source = try? await asset.loadTracks(withMediaType: .video).first else {
                continue
            }

            let range = CMTimeRange(start: .zero, duration: duration)
            try? video.insertTimeRange(range, of: source, at: cursor)
            if let sound = try? await asset.loadTracks(withMediaType: .audio).first {
                try? audio?.insertTimeRange(range, of: sound, at: cursor)
            }
            let transform = (try? await source.load(.preferredTransform)) ?? .identity
            if renderSize == .zero {
                renderSize = await Self.renderSize(of: source, transform: transform)
            }
            layer.setTransform(transform, at: cursor)
            cursor = CMTimeAdd(cursor, duration)
        }

        let target = store.reserve(.video, extension: "mp4").url

        return await export(
            composition,
            layer: layer,
            renderSize: renderSize,
            duration: cursor,
            to: target,
            cleanup: segments
        )
    }

    private static func renderSize(of track: AVAssetTrack, transform: CGAffineTransform) async -> CGSize {
        let size = ((try? await track.load(.naturalSize)) ?? .zero).applying(transform)

        return CGSize(width: abs(size.width), height: abs(size.height))
    }

    private static func export(
        _ composition: AVMutableComposition,
        layer: AVMutableVideoCompositionLayerInstruction,
        renderSize: CGSize,
        duration: CMTime,
        to target: URL,
        cleanup: [URL]
    ) async -> URL? {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layer]
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        let preset = AVAssetExportPresetMediumQuality
        guard let session = AVAssetExportSession(asset: composition, presetName: preset) else {
            return cleanup.first
        }

        session.videoComposition = videoComposition
        session.outputURL = target
        session.outputFileType = .mp4
        let box = ExportBox(session: session)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            box.session.exportAsynchronously {
                continuation.resume()
            }
        }
        guard FileManager.default.fileExists(atPath: target.path) else {
            return cleanup.first
        }

        for url in cleanup {
            try? FileManager.default.removeItem(at: url)
        }

        return target
    }
}

private struct ExportBox: @unchecked Sendable {
    let session: AVAssetExportSession
}
