import AVFoundation
import UIKit

@MainActor
public final class CameraSession: NSObject {
    public enum Flash: CaseIterable, Sendable {
        case auto
        case on
        case off

        var symbol: String {
            switch self {
            case .auto:
                "bolt.badge.automatic.fill"
            case .on:
                "bolt.fill"
            case .off:
                "bolt.slash.fill"
            }
        }

        var mode: AVCaptureDevice.FlashMode {
            switch self {
            case .auto:
                .auto
            case .on:
                .on
            case .off:
                .off
            }
        }
    }

    public let session = AVCaptureSession()
    public let preview: AVCaptureVideoPreviewLayer
    public private(set) var position = AVCaptureDevice.Position.back
    public private(set) var isRecording = false
    public var flash = Flash.auto
    public var onCode: (@MainActor (String) -> Void)?
    public var captureRotation: CGFloat = 90
    public var previewRotation: CGFloat = 90 {
        didSet {
            if let connection = preview.connection {
                Self.rotate(connection, to: previewRotation)
            }
        }
    }

    private let makeVideoURL: @MainActor () -> URL
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "airlance.chat.camera")
    private var videoInput: AVCaptureDeviceInput?
    private var hasAudio = false
    private var photoHandlers: [Int64: @MainActor (UIImage?) -> Void] = [:]
    private var onRecorded: (@MainActor (URL?) -> Void)?

    var device: AVCaptureDevice? {
        videoInput?.device
    }

    public init?(makeVideoURL: @escaping @MainActor () -> URL) {
        self.makeVideoURL = makeVideoURL
        preview = AVCaptureVideoPreviewLayer(session: session)
        super.init()
        preview.videoGravity = .resizeAspectFill
        session.beginConfiguration()
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        let configured = attachCamera(.back) && attachOutputs()
        session.commitConfiguration()
        guard configured else {
            return nil
        }

        orient()
        resetZoom()
    }

    public func start() {
        let box = SessionBox(session: session)
        queue.async {
            if !box.session.isRunning {
                box.session.startRunning()
            }
        }
    }

    public func stop() {
        let box = SessionBox(session: session)
        queue.async {
            box.session.stopRunning()
        }
    }

    public func switchPosition() {
        let next: AVCaptureDevice.Position = position == .back ? .front : .back
        session.beginConfiguration()
        if let videoInput {
            session.removeInput(videoInput)
        }
        if !attachCamera(next) {
            _ = attachCamera(position)
        }
        session.commitConfiguration()
        orient()
        resetZoom()
    }

    public func enableAudio() {
        guard !hasAudio, let microphone = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: microphone) else {
            return
        }

        session.beginConfiguration()
        if session.canAddInput(input) {
            session.addInput(input)
            hasAudio = true
        }
        session.commitConfiguration()
    }

    public func focus(at point: CGPoint) {
        guard let device, (try? device.lockForConfiguration()) != nil else {
            return
        }

        let target = preview.captureDevicePointConverted(fromLayerPoint: point)
        if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
            device.focusPointOfInterest = target
            device.focusMode = .autoFocus
        }
        if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
            device.exposurePointOfInterest = target
            device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()
    }

    func newVideoURL() -> URL {
        makeVideoURL()
    }

    public func capturePhoto(fast: Bool = false, _ completion: @escaping @MainActor (UIImage?) -> Void) {
        let settings = AVCapturePhotoSettings()
        if fast {
            settings.photoQualityPrioritization = .speed
        }
        if let connection = photoOutput.connection(with: .video) {
            Self.rotate(connection, to: captureRotation)
        }
        if photoOutput.supportedFlashModes.contains(flash.mode) {
            settings.flashMode = flash.mode
        }
        photoHandlers[settings.uniqueID] = completion
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    public func startRecording() {
        guard !isRecording else {
            return
        }

        isRecording = true
        if let connection = movieOutput.connection(with: .video) {
            Self.rotate(connection, to: captureRotation)
        }
        movieOutput.startRecording(to: makeVideoURL(), recordingDelegate: self)
    }

    public func stopRecording(_ completion: @escaping @MainActor (URL?) -> Void) {
        guard isRecording else {
            completion(nil)

            return
        }

        onRecorded = completion
        movieOutput.stopRecording()
    }

    private func attachCamera(_ next: AVCaptureDevice.Position) -> Bool {
        guard
            let device = Self.camera(at: next),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            return false
        }

        session.addInput(input)
        videoInput = input
        position = next

        return true
    }

    private func attachOutputs() -> Bool {
        guard session.canAddOutput(photoOutput), session.canAddOutput(movieOutput) else {
            return false
        }

        session.addOutput(photoOutput)
        session.addOutput(movieOutput)
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                metadataOutput.metadataObjectTypes = [.qr]
                metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            }
        }
        if let dimensions = device?.activeFormat.supportedMaxPhotoDimensions.last {
            photoOutput.maxPhotoDimensions = dimensions
        }

        return true
    }

    private func orient() {
        let isFront = position == .front
        let connections = [
            preview.connection,
            photoOutput.connection(with: .video),
            movieOutput.connection(with: .video),
        ]
        for connection in connections.compactMap(\.self) {
            Self.rotate(connection, to: connection === preview.connection ? previewRotation : captureRotation)
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isFront
            }
        }
    }

    fileprivate func deliverPhoto(_ id: Int64, data: Data?) {
        let image = data.flatMap(UIImage.init(data:))
        photoHandlers.removeValue(forKey: id)?(image)
    }

    static func rotate(_ connection: AVCaptureConnection, to angle: CGFloat) {
        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = switch angle {
            case 0:
                .landscapeRight
            case 180:
                .landscapeLeft
            case 270:
                .portraitUpsideDown
            default:
                .portrait
            }
        }
    }

    fileprivate func deliverMovie(_ url: URL, failed: Bool) {
        isRecording = false
        let handler = onRecorded
        onRecorded = nil
        handler?(failed ? nil : url)
    }
}

extension CameraSession: AVCapturePhotoCaptureDelegate {
    nonisolated public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        let id = photo.resolvedSettings.uniqueID
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            self.deliverPhoto(id, data: data)
        }
    }
}

extension CameraSession: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated public func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let codes = metadataObjects.compactMap { object in
            (object as? AVMetadataMachineReadableCodeObject)?.stringValue
        }
        guard let code = codes.first else {
            return
        }

        Task { @MainActor in
            self.onCode?(code)
        }
    }
}

extension CameraSession: AVCaptureFileOutputRecordingDelegate {
    nonisolated public func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        let failed = error.map { error in
            (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool != true
        } ?? false
        Task { @MainActor in
            self.deliverMovie(outputFileURL, failed: failed)
        }
    }
}

private struct SessionBox: @unchecked Sendable {
    let session: AVCaptureSession
}
