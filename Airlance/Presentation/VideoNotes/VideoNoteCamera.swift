import AVFoundation
import MediaStore
import UIKit

@MainActor
final class VideoNoteCamera: NSObject {
    struct Result {
        let main: URL
        let front: URL?
        let duration: TimeInterval
        let levels: [Float]
    }

    let session: AVCaptureSession
    let mainPreview: AVCaptureVideoPreviewLayer
    let stylized: StylizedCapture?
    let store: MediaStore
    var frontPreview: AVCaptureVideoPreviewLayer?
    var position = AVCaptureDevice.Position.front
    var videoInput: AVCaptureDeviceInput?
    var segments: [URL] = []
    var isSwitching = false
    let mainOutput = AVCaptureMovieFileOutput()
    var frontOutput: AVCaptureMovieFileOutput?
    var frontURL: URL?
    private let queue = DispatchQueue(label: "airlance.videonote.camera")
    private var onStopped: ((Result?) -> Void)?
    private var waiting: Set<URL> = []
    private var startDate: Date?
    private var samples: [Float] = []

    var isDual: Bool {
        frontOutput != nil
    }

    var canSwitch: Bool {
        !isDual && AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    init?(dual: Bool, stylized: Bool, store: MediaStore) {
        self.store = store
        let useMulti = dual && AVCaptureMultiCamSession.isMultiCamSupported
        session = useMulti ? AVCaptureMultiCamSession() : AVCaptureSession()
        mainPreview = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        self.stylized = stylized && !dual ? StylizedCapture() : nil
        super.init()
        session.beginConfiguration()
        let configured = useMulti ? configureDual() : configureSingle(position: dual ? .back : .front)
        session.commitConfiguration()
        guard configured else {
            return nil
        }
    }

    private func configureSingle(position: AVCaptureDevice.Position) -> Bool {
        self.position = position
        let preset: AVCaptureSession.Preset = stylized == nil ? .high : .vga640x480
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else {
            return false
        }

        session.addInput(input)
        videoInput = input
        if let microphone = AVCaptureDevice.default(for: .audio),
           let audio = try? AVCaptureDeviceInput(device: microphone), session.canAddInput(audio) {
            session.addInput(audio)
        }
        if let stylized {
            guard stylized.attach(to: session) else {
                return false
            }
        } else {
            guard session.canAddOutput(mainOutput) else {
                return false
            }

            session.addOutput(mainOutput)
            mainPreview.session = session
        }
        orientConnections()

        return true
    }

    func orientConnections() {
        let isFront = position == .front
        let connections = [
            mainPreview.connection,
            mainOutput.connection(with: .video),
            stylized?.videoOutput.connection(with: .video),
        ]
        for connection in connections.compactMap(\.self) {
            Self.portrait(connection)
            Self.mirror(isFront)(connection)
        }
    }

    private func configureDual() -> Bool {
        guard connect(.back, output: mainOutput, preview: mainPreview) != nil else {
            return false
        }

        position = .back
        let front = AVCaptureMovieFileOutput()
        let preview = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        if connect(.front, output: front, preview: preview) != nil {
            frontOutput = front
            frontPreview = preview
        }
        if let microphone = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: microphone), session.canAddInput(input) {
            session.addInputWithNoConnections(input)
            if let port = input.ports(for: .audio, sourceDeviceType: nil, sourceDevicePosition: .unspecified).first {
                let connection = AVCaptureConnection(inputPorts: [port], output: mainOutput)
                if session.canAddConnection(connection) {
                    session.addConnection(connection)
                }
            }
        }

        return true
    }

    private func connect(
        _ position: AVCaptureDevice.Position,
        output: AVCaptureMovieFileOutput,
        preview: AVCaptureVideoPreviewLayer
    ) -> Bool? {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input),
              session.canAddOutput(output) else {
            return nil
        }

        session.addInputWithNoConnections(input)
        session.addOutputWithNoConnections(output)
        guard let port = input.ports(for: .video, sourceDeviceType: camera.deviceType, sourceDevicePosition: position)
            .first else {
            return nil
        }

        let connection = AVCaptureConnection(inputPorts: [port], output: output)
        let previewConnection = AVCaptureConnection(inputPort: port, videoPreviewLayer: preview)
        guard session.canAddConnection(connection), session.canAddConnection(previewConnection) else {
            return nil
        }

        session.addConnection(connection)
        session.addConnection(previewConnection)
        Self.mirror(position == .front)(connection)
        Self.mirror(position == .front)(previewConnection)

        return true
    }

    static func mirror(_ isMirrored: Bool) -> (AVCaptureConnection) -> Void {
        { connection in
            guard connection.isVideoMirroringSupported else {
                return
            }

            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }

    private static func portrait(_ connection: AVCaptureConnection) {
        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    func start() {
        let box = SessionBox(session: session)
        queue.async {
            box.session.startRunning()
        }
    }

    func shutdown() {
        let box = SessionBox(session: session)
        queue.async {
            box.session.stopRunning()
        }
    }

    func newURL(_ ext: String) -> URL {
        store.reserve(.video, extension: ext).url
    }

    func record() {
        startDate = Date()
        samples = []
        segments = []
        if let stylized {
            let url = newURL("mp4")
            segments = [url]
            stylized.start(to: url)

            return
        }

        startSegment()
        if let frontOutput {
            let url = newURL("mov")
            frontURL = url
            frontOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func startSegment() {
        let url = newURL("mov")
        segments.append(url)
        mainOutput.startRecording(to: url, recordingDelegate: self)
    }

    var duration: TimeInterval {
        startDate.map { date in
            Date().timeIntervalSince(date)
        } ?? 0
    }

    func sampleLevel() -> CGFloat {
        let connection = stylized?.audioOutput.connection(with: .audio) ?? mainOutput.connection(with: .audio)
        let power = connection?.audioChannels.first?.averagePowerLevel ?? -60
        let value = min(max((power + 50) / 50, 0), 1)
        samples.append(value)

        return CGFloat(value)
    }

    func stop(_ completion: @escaping (Result?) -> Void) {
        onStopped = completion
        let duration = duration
        if let stylized {
            stylized.finish { url in
                Task { @MainActor in
                    self.deliver(url, front: nil, duration: duration)
                }
            }

            return
        }

        var expected = Array(segments.suffix(1))
        if let frontURL {
            expected.append(frontURL)
        }
        waiting = Set(expected)
        isSwitching = false
        mainOutput.stopRecording()
        frontOutput?.stopRecording()
    }

    fileprivate func finished(_ url: URL) {
        if isSwitching, segments.last == url {
            isSwitching = false
            swapInput()
            startSegment()

            return
        }

        waiting.remove(url)
        guard waiting.isEmpty, onStopped != nil else {
            return
        }

        let segments = segments
        let front = frontURL
        let duration = duration
        Task {
            let main = await VideoNoteProcessor.merge(segments, store: self.store)
            self.deliver(main, front: front, duration: duration)
        }
    }

    private func deliver(_ main: URL?, front: URL?, duration: TimeInterval) {
        let result = main.map { main in
            Result(main: main, front: front, duration: duration, levels: samples)
        }
        onStopped?(result)
        onStopped = nil
    }
}

extension VideoNoteCamera: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.finished(outputFileURL)
        }
    }
}

struct SessionBox: @unchecked Sendable {
    let session: AVCaptureSession
}
