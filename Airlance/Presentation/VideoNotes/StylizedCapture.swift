import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

final class StylizedCapture: NSObject, @unchecked Sendable {
    let videoOutput = AVCaptureVideoDataOutput()
    let audioOutput = AVCaptureAudioDataOutput()
    var onPreview: (@Sendable (CGImage) -> Void)?

    private let queue = DispatchQueue(label: "airlance.videonote.stylized")
    private let context = CIContext()
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var url: URL?
    private var wantsRecording = false
    private var isStarted = false

    func attach(to session: AVCaptureSession) -> Bool {
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput), session.canAddOutput(audioOutput) else {
            return false
        }

        session.addOutput(videoOutput)
        session.addOutput(audioOutput)
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        audioOutput.setSampleBufferDelegate(self, queue: queue)

        return true
    }

    func start(to url: URL) {
        queue.async {
            self.url = url
            self.wantsRecording = true
        }
    }

    func finish(_ completion: @escaping @Sendable (URL?) -> Void) {
        queue.async {
            self.wantsRecording = false
            guard let writer = self.writer, self.isStarted else {
                completion(nil)

                return
            }

            let url = self.url
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()
            self.writer = nil
            self.isStarted = false
            writer.finishWriting {
                completion(writer.status == .completed ? url : nil)
            }
        }
    }

    static func stylize(_ image: CIImage) -> CIImage {
        let points = CIFilter.pointillize()
        points.inputImage = image.clampedToExtent()
        points.radius = Float(max(image.extent.width, image.extent.height) / 80)
        let colors = CIFilter.colorControls()
        colors.inputImage = points.outputImage
        colors.saturation = 1.35
        colors.contrast = 1.1

        return colors.outputImage?.cropped(to: image.extent) ?? image
    }

    private func makeWriter(size: CGSize) {
        guard let url, let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            return
        }

        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_200_000],
        ])
        video.expectsMediaDataInRealTime = true
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ])
        audio.expectsMediaDataInRealTime = true
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]
        if writer.canAdd(video) {
            writer.add(video)
        }
        if writer.canAdd(audio) {
            writer.add(audio)
        }
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: attributes)
        self.writer = writer
        videoInput = video
        audioInput = audio
    }

    private func handleVideo(_ sampleBuffer: CMSampleBuffer) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let image = CIImage(cvPixelBuffer: pixels)
        let styled = Self.stylize(image)
        if let preview = context.createCGImage(styled, from: image.extent) {
            onPreview?(preview)
        }
        guard wantsRecording else {
            return
        }

        if writer == nil {
            makeWriter(size: image.extent.size)
        }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard let writer, let videoInput, let adaptor else {
            return
        }

        if !isStarted {
            guard writer.startWriting() else {
                return
            }

            writer.startSession(atSourceTime: time)
            isStarted = true
        }
        guard videoInput.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else {
            return
        }

        var output: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &output)
        guard let output else {
            return
        }

        context.render(styled, to: output, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        adaptor.append(output, withPresentationTime: time)
    }

    private func handleAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isStarted, let audioInput, audioInput.isReadyForMoreMediaData else {
            return
        }

        audioInput.append(sampleBuffer)
    }
}

extension StylizedCapture: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output === videoOutput {
            handleVideo(sampleBuffer)
        } else {
            handleAudio(sampleBuffer)
        }
    }
}
