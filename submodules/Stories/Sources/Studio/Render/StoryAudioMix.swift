import AVFoundation

@MainActor
enum StoryAudioMix {
    static func make(
        _ sound: StorySound,
        in composition: AVMutableComposition,
        original: AVMutableCompositionTrack?,
        duration: CMTime
    ) async -> AVAudioMix? {
        var parameters: [AVMutableAudioMixInputParameters] = []
        if let original {
            let input = AVMutableAudioMixInputParameters(track: original)
            input.setVolume(sound.originalVolume, at: .zero)
            parameters.append(input)
        }
        if let track = sound.track,
           let (added, span) = await insert(track.url, from: track.start, length: duration.seconds, into: composition) {
            let input = AVMutableAudioMixInputParameters(track: added)
            input.setVolume(track.volume, at: .zero)
            let fade = min(0.6, span / 4)
            input.setVolumeRamp(
                fromStartVolume: track.volume,
                toEndVolume: 0,
                timeRange: CMTimeRange(
                    start: CMTime(seconds: span - fade, preferredTimescale: 600),
                    duration: CMTime(seconds: fade, preferredTimescale: 600)
                )
            )
            parameters.append(input)
        }
        if let voice = sound.voice,
           let (added, _) = await insert(voice.url, from: 0, length: duration.seconds, into: composition) {
            let input = AVMutableAudioMixInputParameters(track: added)
            input.setVolume(voice.volume, at: .zero)
            parameters.append(input)
        }
        guard !parameters.isEmpty else {
            return nil
        }

        let mix = AVMutableAudioMix()
        mix.inputParameters = parameters

        return mix
    }

    private static func insert(
        _ url: URL,
        from start: TimeInterval,
        length: TimeInterval,
        into composition: AVMutableComposition
    ) async -> (AVMutableCompositionTrack, TimeInterval)? {
        let asset = AVURLAsset(url: url)
        guard let source = try? await asset.loadTracks(withMediaType: .audio).first,
              let total = try? await asset.load(.duration) else {
            return nil
        }

        let span = min(length, max(0, total.seconds - start))
        guard span > 0.05 else {
            return nil
        }

        let range = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: span, preferredTimescale: 600)
        )
        let trackID = kCMPersistentTrackID_Invalid
        guard let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: trackID),
              (try? target.insertTimeRange(range, of: source, at: .zero)) != nil else {
            return nil
        }

        return (target, span)
    }
}
