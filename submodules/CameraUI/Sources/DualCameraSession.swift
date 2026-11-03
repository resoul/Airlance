import AVFoundation
import UIKit

@MainActor
final class DualCameraSession: NSObject {
    static var isSupported: Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }

    let backPreview: AVCaptureVideoPreviewLayer
    let frontPreview: AVCaptureVideoPreviewLayer
    private(set) var isRecording = false

    private let session = AVCaptureMultiCamSession()
    private let backOutput = AVCaptureMovieFileOutput()
    private let frontOutput = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "airlance.camera.dual")
    private let makeURL: @MainActor () -> URL
    private var hasAudio = false
    private var pending: [URL: URL?] = [:]
    private var urls: (back: URL, front: URL)?
    private var onStopped: (@MainActor (URL?, URL?) -> Void)?

    init?(makeURL: @escaping @MainActor () -> URL) {
        guard Self.isSupported else {
            return nil
        }

        self.makeURL = makeURL
        backPreview = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontPreview = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        super.init()
        backPreview.videoGravity = .resizeAspectFill
        frontPreview.videoGravity = .resizeAspectFill
        session.beginConfiguration()
        let configured = connect(.back, output: backOutput, preview: backPreview)
            && connect(.front, output: frontOutput, preview: frontPreview)
        session.commitConfiguration()
        guard configured else {
            return nil
        }
    }

    func start() {
        let box = DualSessionBox(session: session)
        queue.async {
            box.session.startRunning()
        }
    }

    func stop() {
        let box = DualSessionBox(session: session)
        queue.async {
            box.session.stopRunning()
        }
    }

    func addAudio() {
        guard !hasAudio, let microphone = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: microphone), session.canAddInput(input) else {
            return
        }

        session.beginConfiguration()
        session.addInputWithNoConnections(input)
        if let port = input.ports(for: .audio, sourceDeviceType: nil, sourceDevicePosition: .unspecified).first {
            let connection = AVCaptureConnection(inputPorts: [port], output: backOutput)
            if session.canAddConnection(connection) {
                session.addConnection(connection)
                hasAudio = true
            }
        }
        session.commitConfiguration()
    }

    func startRecording(rotation: CGFloat) {
        guard !isRecording else {
            return
        }

        let back = makeURL()
        let front = makeURL()
        urls = (back, front)
        pending = [:]
        isRecording = true
        for output in [backOutput, frontOutput] {
            if let connection = output.connection(with: .video) {
                CameraSession.rotate(connection, to: rotation)
            }
        }
        backOutput.startRecording(to: back, recordingDelegate: self)
        frontOutput.startRecording(to: front, recordingDelegate: self)
    }

    func stopRecording(_ completion: @escaping @MainActor (URL?, URL?) -> Void) {
        guard isRecording else {
            completion(nil, nil)

            return
        }

        onStopped = completion
        backOutput.stopRecording()
        frontOutput.stopRecording()
    }

    private func connect(
        _ position: AVCaptureDevice.Position,
        output: AVCaptureMovieFileOutput,
        preview: AVCaptureVideoPreviewLayer
    ) -> Bool {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input),
              session.canAddOutput(output) else {
            return false
        }

        session.addInputWithNoConnections(input)
        session.addOutputWithNoConnections(output)
        guard let port = input.ports(for: .video, sourceDeviceType: camera.deviceType, sourceDevicePosition: position)
            .first else {
            return false
        }

        let connection = AVCaptureConnection(inputPorts: [port], output: output)
        let previewConnection = AVCaptureConnection(inputPort: port, videoPreviewLayer: preview)
        guard session.canAddConnection(connection), session.canAddConnection(previewConnection) else {
            return false
        }

        session.addConnection(connection)
        session.addConnection(previewConnection)
        for item in [connection, previewConnection] {
            CameraSession.rotate(item, to: 90)
            if item.isVideoMirroringSupported {
                item.automaticallyAdjustsVideoMirroring = false
                item.isVideoMirrored = position == .front
            }
        }

        return true
    }

    fileprivate func finished(_ url: URL, failed: Bool) {
        pending[url] = failed ? URL?.none : url
        guard let urls, pending.count == 2 else {
            return
        }

        isRecording = false
        let back = pending[urls.back] ?? nil
        let front = pending[urls.front] ?? nil
        let handler = onStopped
        onStopped = nil
        self.urls = nil
        handler?(back, front)
    }
}

extension DualCameraSession: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        let failed = error.map { error in
            (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool != true
        } ?? false
        Task { @MainActor in
            self.finished(outputFileURL, failed: failed)
        }
    }
}

private struct DualSessionBox: @unchecked Sendable {
    let session: AVCaptureMultiCamSession
}
