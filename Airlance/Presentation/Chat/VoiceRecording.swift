import AVFoundation
import ChatHistory
import Foundation
import MediaStore

@MainActor
final class VoiceRecording {
    private static let bars = 40

    private let recorder: AVAudioRecorder
    private var samples: [Float] = []

    var level: CGFloat {
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let value = min(max((power + 50) / 50, 0), 1)
        samples.append(value)

        return CGFloat(value)
    }

    var duration: TimeInterval {
        recorder.currentTime
    }

    private let media: LocalMedia

    init?(store: MediaStore) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let (media, url) = store.reserve(.voice, extension: "m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ]
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else {
            return nil
        }

        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            return nil
        }

        self.recorder = recorder
        self.media = media
    }

    func finish() -> MessageVoice {
        let duration = recorder.currentTime
        recorder.stop()

        return MessageVoice(source: .local(media), duration: duration, waveform: waveform())
    }

    func cancel() {
        recorder.stop()
        recorder.deleteRecording()
    }

    private func waveform() -> [UInt8] {
        guard !samples.isEmpty else {
            return Array(repeating: 2, count: Self.bars)
        }

        let step = Float(samples.count) / Float(Self.bars)
        let values = (0..<Self.bars).map { bar in
            let start = Int(Float(bar) * step)
            let end = max(start + 1, min(samples.count, Int(Float(bar + 1) * step)))

            return samples[start..<end].max() ?? 0
        }
        let peak = max(values.max() ?? 1, 0.01)

        return values.map { value in
            UInt8(max(2, min(31, (value / peak * 31).rounded())))
        }
    }
}
