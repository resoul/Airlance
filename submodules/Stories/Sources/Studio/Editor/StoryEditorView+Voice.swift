import AVFoundation
import Haptics
import UIKit

extension StoryEditorView {
    func applySound() {
        let isMuted = recorder != nil
        player?.volume = isMuted ? 0 : sound.originalVolume
        trackPlayer = reuse(trackPlayer, url: sound.track?.url)
        voicePlayer = reuse(voicePlayer, url: sound.voice?.url)
        trackPlayer?.volume = isMuted ? 0 : sound.track?.volume ?? 1
        voicePlayer?.volume = isMuted ? 0 : sound.voice?.volume ?? 1
        guard sound.hasAudio || isMuted else {
            soundClock?.invalidate()
            soundClock = nil

            return
        }

        try? AVAudioSession.sharedInstance().setCategory(isMuted ? .playAndRecord : .playback, options: isMuted ? [
            .defaultToSpeaker,
        ] : [])
        guard soundClock == nil else {
            return
        }

        let clock = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tickSound()
            }
        }
        RunLoop.main.add(clock, forMode: .common)
        soundClock = clock
    }

    func restartSound() {
        clockStart = Date()
        lastStoryTime = .greatestFiniteMagnitude
        if let player {
            let start = CMTime(seconds: trim?.start ?? 0, preferredTimescale: 600)
            player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func stopSound() {
        soundClock?.invalidate()
        soundClock = nil
        trackPlayer?.pause()
        voicePlayer?.pause()
        trackPlayer = nil
        voicePlayer = nil
        if let recorder {
            recorder.stop()
            recorder.deleteRecording()
            self.recorder = nil
        }
    }

    func startRecording(to url: URL) {
        guard isHoldingRecord, recorder == nil else {
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings), recorder.record() else {
            Haptics.play(.error)

            return
        }

        self.recorder = recorder
        soundPanel?.setRecording(true)
        Haptics.play(.tap)
        applySound()
        restartSound()
    }

    func holdRecord(_ isHolding: Bool) {
        isHoldingRecord = isHolding
        if isHolding {
            onRecordVoice?()
        } else {
            finishRecording()
        }
    }

    private func finishRecording() {
        guard let recorder else {
            return
        }

        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        soundPanel?.setRecording(false)
        if duration > 0.5 {
            if let old = sound.voice {
                try? FileManager.default.removeItem(at: old.url)
            }
            sound.voice = StoryVoice(url: recorder.url, duration: min(duration, storyLength))
            Haptics.play(.success)
        } else {
            recorder.deleteRecording()
        }
        soundPanel?.set(sound: sound)
        applySound()
        restartSound()
        setNeedsLayout()
    }

    private func reuse(_ current: AVPlayer?, url: URL?) -> AVPlayer? {
        guard let url else {
            current?.pause()

            return nil
        }

        if let asset = current?.currentItem?.asset as? AVURLAsset, asset.url == url {
            return current
        }

        current?.pause()
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        lastStoryTime = .greatestFiniteMagnitude

        return player
    }

    private var storyTime: TimeInterval {
        guard let player else {
            return Date().timeIntervalSince(clockStart).truncatingRemainder(dividingBy: storyLength)
        }

        return max(0, player.currentTime().seconds - (trim?.start ?? 0))
    }

    private func tickSound() {
        let time = storyTime
        if let recorder, recorder.currentTime >= storyLength {
            isHoldingRecord = false
            finishRecording()

            return
        }

        if time + 0.15 < lastStoryTime {
            sync(at: time)
        }
        lastStoryTime = time
    }

    private func sync(at time: TimeInterval) {
        if let track = sound.track, let trackPlayer {
            trackPlayer.seek(to: CMTime(seconds: track.start + time, preferredTimescale: 600))
            trackPlayer.play()
        }
        if let voice = sound.voice, let voicePlayer, time < voice.duration {
            voicePlayer.seek(to: CMTime(seconds: time, preferredTimescale: 600))
            voicePlayer.play()
        }
    }
}
