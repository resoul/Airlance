import AVFoundation
import MediaStore
import MusicPlayer
import UIKit

@MainActor
final class VideoNoteCamera: NSObject {
    struct Result {
        let main: URL
        let duration: TimeInterval
        let levels: [Float]
    }

    let session: AVCaptureSession
    let mainPreview: AVCaptureVideoPreviewLayer
    let store: MediaStore
    var position = AVCaptureDevice.Position.front
    var videoInput: AVCaptureDeviceInput?
    var segments: [URL] = []
    var isSwitching = false
    let mainOutput = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "airlance.videonote.camera")
    private var onStopped: ((Result?) -> Void)?
    private var waiting: Set<URL> = []
    private var startDate: Date?
    private var samples: [Float] = []

    var canSwitch: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    init?(store: MediaStore) {
        self.store = store
        session = AVCaptureSession()
        mainPreview = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        super.init()
        session.beginConfiguration()
        let configured = configureSingle(position: .front)
        session.commitConfiguration()
        guard configured else {
            return nil
        }
    }

    private func configureSingle(position: AVCaptureDevice.Position) -> Bool {
        self.position = position
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
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
        guard session.canAddOutput(mainOutput) else {
            return false
        }

        session.addOutput(mainOutput)
        mainPreview.session = session
        orientConnections()

        return true
    }

    func orientConnections() {
        let isFront = position == .front
        let connections = [
            mainPreview.connection,
            mainOutput.connection(with: .video),
        ]
        for connection in connections.compactMap(\.self) {
            Self.portrait(connection)
            Self.mirror(isFront)(connection)
        }
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
        AudioSessionQueue.run {
            try? AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
        }
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
        startSegment()
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
        let connection = mainOutput.connection(with: .audio)
        let power = connection?.audioChannels.first?.averagePowerLevel ?? -60
        let value = min(max((power + 50) / 50, 0), 1)
        samples.append(value)

        return CGFloat(value)
    }

    func stop(_ completion: @escaping (Result?) -> Void) {
        onStopped = completion
        waiting = Set(segments.suffix(1))
        isSwitching = false
        mainOutput.stopRecording()
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
        let duration = duration
        Task {
            let main = await VideoNoteProcessor.merge(segments, store: self.store)
            self.deliver(main, duration: duration)
        }
    }

    private func deliver(_ main: URL?, duration: TimeInterval) {
        let result = main.map { main in
            Result(main: main, duration: duration, levels: samples)
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
