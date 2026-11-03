import AVFoundation
import CoreGraphics
import CoreVideo

enum LoopMaker {
    static let duration: TimeInterval = 1.2

    private static let frameCount = 18
    private static let passes = 3
    private static let rate: Int32 = 18
    private static let maxSize = CGSize(width: 720, height: 1280)

    nonisolated static func make(from source: URL, to output: URL) async -> Bool {
        let asset = AVURLAsset(url: source)
        guard let length = try? await asset.load(.duration), length.seconds > 0.2 else {
            return false
        }

        let frames = await images(of: asset, length: length.seconds)
        guard let first = frames.first else {
            return false
        }

        let order = Array(frames.indices) + Array(frames.indices.dropFirst().dropLast().reversed())
        let sequence = (0..<passes).flatMap { _ in
            order.map { index in
                frames[index]
            }
        }

        return await write(sequence, size: CGSize(width: first.width, height: first.height), to: output)
    }

    nonisolated private static func images(of asset: AVURLAsset, length: TimeInterval) async -> [CGImage] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        let tolerance = CMTime(value: 1, timescale: 60)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        let start = min(0.05, length / 10)
        let step = (length - start) / Double(frameCount)
        var frames: [CGImage] = []
        for index in 0..<frameCount {
            let time = CMTime(seconds: start + step * Double(index), preferredTimescale: 600)
            if let image = try? await generator.image(at: time).image {
                frames.append(image)
            }
        }

        return frames
    }

    nonisolated private static func write(_ frames: [CGImage], size: CGSize, to output: URL) async -> Bool {
        try? FileManager.default.removeItem(at: output)
        guard let writer = try? AVAssetWriter(outputURL: output, fileType: .mov) else {
            return false
        }

        let width = Int(size.width) / 2 * 2
        let height = Int(size.height) / 2 * 2
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else {
            return false
        }

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for (index, frame) in frames.enumerated() {
            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let buffer = pixelBuffer(frame, adaptor: adaptor, width: width, height: height) else {
                continue
            }

            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: rate))
        }
        input.markAsFinished()
        await writer.finishWriting()

        return writer.status == .completed
    }

    nonisolated private static func pixelBuffer(
        _ image: CGImage,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        width: Int,
        height: Int
    ) -> CVPixelBuffer? {
        var created: CVPixelBuffer?
        if let pool = adaptor.pixelBufferPool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created)
        }
        guard let buffer = created else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: info
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
