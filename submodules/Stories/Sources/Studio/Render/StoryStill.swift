import AVFoundation
import UIKit

@MainActor
enum StoryStill {
    static func photo(
        _ url: URL,
        sound: StorySound,
        aspect: CGSize,
        makeURL: @MainActor (String) -> URL
    ) async -> URL? {
        guard let image = UIImage(contentsOfFile: url.path),
              let still = await video(from: image, duration: StorySound.photoDuration, makeURL: makeURL) else {
            return nil
        }

        try? FileManager.default.removeItem(at: url)
        var options = StoryRenderOptions()
        options.sound = sound

        return await StoryExport.video(
            still,
            overlay: nil,
            subtitles: nil,
            aspect: aspect,
            options: options,
            keepsSource: false,
            makeURL: makeURL
        )
    }

    static func video(from image: UIImage, duration: TimeInterval, makeURL: @MainActor (String) -> URL) async -> URL? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = cgImage.width / 2 * 2
        let height = cgImage.height / 2 * 2
        let target = makeURL("mp4")
        guard let writer = try? AVAssetWriter(outputURL: target, fileType: .mp4) else {
            return nil
        }

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        guard writer.startWriting(), let buffer = pixelBuffer(cgImage, width: width, height: height) else {
            return nil
        }

        writer.startSession(atSourceTime: .zero)
        let end = CMTime(seconds: duration, preferredTimescale: 600)
        for time in [CMTime.zero, end] {
            await waitUntilReady(input)
            adaptor.append(buffer, withPresentationTime: time)
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: end)
        let box = StoryWriterBox(writer: writer)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            box.writer.finishWriting {
                continuation.resume()
            }
        }

        return writer.status == .completed ? target : nil
    }

    private static func waitUntilReady(_ input: AVAssetWriterInput) async {
        var attempts = 0
        while !input.isReadyForMoreMediaData, attempts < 200 {
            attempts += 1
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private static func pixelBuffer(_ image: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, nil, &buffer)
        guard let buffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}

private struct StoryWriterBox: @unchecked Sendable {
    let writer: AVAssetWriter
}
