import AVFoundation
import CoreGraphics

enum DualComposer {
    nonisolated static func compose(back: URL, front: URL, pip: CGRect, to output: URL) async -> Bool {
        let backAsset = AVURLAsset(url: back)
        let frontAsset = AVURLAsset(url: front)
        guard
            let backSource = try? await backAsset.loadTracks(withMediaType: .video).first,
            let frontSource = try? await frontAsset.loadTracks(withMediaType: .video).first,
            let backDuration = try? await backAsset.load(.duration),
            let frontDuration = try? await frontAsset.load(.duration)
        else {
            return false
        }

        let duration = CMTimeMinimum(backDuration, frontDuration)
        let range = CMTimeRange(start: .zero, duration: duration)
        let composition = AVMutableComposition()
        let trackID = kCMPersistentTrackID_Invalid
        guard
            let backTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: trackID),
            let frontTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: trackID),
            (try? backTrack.insertTimeRange(range, of: backSource, at: .zero)) != nil,
            (try? frontTrack.insertTimeRange(range, of: frontSource, at: .zero)) != nil
        else {
            return false
        }

        if let sound = try? await backAsset.loadTracks(withMediaType: .audio).first,
           let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: trackID) {
            try? audio.insertTimeRange(range, of: sound, at: .zero)
        }
        let backTransform = (try? await backSource.load(.preferredTransform)) ?? .identity
        let frontTransform = (try? await frontSource.load(.preferredTransform)) ?? .identity
        let backSize = oriented((try? await backSource.load(.naturalSize)) ?? .zero, backTransform)
        let frontSize = oriented((try? await frontSource.load(.naturalSize)) ?? .zero, frontTransform)
        guard backSize.width > 0, frontSize.width > 0 else {
            return false
        }

        let backLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: backTrack)
        backLayer.setTransform(backTransform, at: .zero)
        let frontLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: frontTrack)
        frontLayer.setTransform(place(frontTransform, size: frontSize, pip: pip, in: backSize), at: .zero)
        let video = videoComposition(layers: [frontLayer, backLayer], range: range, size: backSize)

        return await export(composition, video: video, to: output)
    }

    nonisolated private static func videoComposition(
        layers: [AVVideoCompositionLayerInstruction],
        range: CMTimeRange,
        size: CGSize
    ) -> AVMutableVideoComposition {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        instruction.layerInstructions = layers
        let video = AVMutableVideoComposition()
        video.instructions = [instruction]
        video.renderSize = CGSize(width: Int(size.width) / 2 * 2, height: Int(size.height) / 2 * 2)
        video.frameDuration = CMTime(value: 1, timescale: 30)

        return video
    }

    nonisolated private static func oriented(_ size: CGSize, _ transform: CGAffineTransform) -> CGSize {
        let rotated = size.applying(transform)

        return CGSize(width: abs(rotated.width), height: abs(rotated.height))
    }

    nonisolated private static func place(
        _ transform: CGAffineTransform,
        size: CGSize,
        pip: CGRect,
        in canvas: CGSize
    ) -> CGAffineTransform {
        let width = pip.width * canvas.width
        let height = pip.height * canvas.height
        let scale = max(width / size.width, height / size.height)
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        let x = pip.minX * canvas.width - (scaledSize.width - width) / 2
        let y = pip.minY * canvas.height - (scaledSize.height - height) / 2

        return transform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: x, y: y))
    }

    nonisolated private static func export(
        _ composition: AVComposition,
        video: AVVideoComposition,
        to output: URL
    ) async -> Bool {
        try? FileManager.default.removeItem(at: output)
        let preset = AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: composition, presetName: preset) else {
            return false
        }

        session.videoComposition = video
        session.outputURL = output
        session.outputFileType = .mov
        let box = DualExportBox(session: session)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            box.session.exportAsynchronously {
                continuation.resume()
            }
        }

        return FileManager.default.fileExists(atPath: output.path)
    }
}

private struct DualExportBox: @unchecked Sendable {
    let session: AVAssetExportSession
}
