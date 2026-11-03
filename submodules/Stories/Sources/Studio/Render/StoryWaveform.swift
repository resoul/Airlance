import AVFoundation

enum StoryWaveform {
    static func samples(of url: URL, count: Int) async -> [Float] {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
                return []
            }

            return resample(peaks(of: asset, track: track), count: count)
        }.value
    }

    static func loudest(_ samples: [Float], window: Int) -> Int {
        guard window > 0, samples.count > window else {
            return 0
        }

        var sum = samples[0..<window].reduce(0, +)
        var best = sum
        var start = 0
        for index in window..<samples.count {
            sum += samples[index] - samples[index - window]
            if sum > best {
                best = sum
                start = index - window + 1
            }
        }

        return start
    }

    private static func peaks(of asset: AVAsset, track: AVAssetTrack) -> [Float] {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 8000,
        ]
        guard let reader = try? AVAssetReader(asset: asset) else {
            return []
        }

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        guard reader.startReading() else {
            return []
        }

        var peaks: [Float] = []
        var peak: Int16 = 0
        var counter = 0
        while let buffer = output.copyNextSampleBuffer() {
            read(buffer) { value in
                peak = max(peak, value == Int16.min ? Int16.max : abs(value))
                counter += 1
                if counter == 400 {
                    peaks.append(Float(peak) / Float(Int16.max))
                    peak = 0
                    counter = 0
                }
            }
        }

        return peaks
    }

    private static func read(_ buffer: CMSampleBuffer, each: (Int16) -> Void) {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else {
            return
        }

        var length = 0
        var pointer: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(
            block,
            atOffset: 0,
            lengthAtOffsetOut: &length,
            totalLengthOut: nil,
            dataPointerOut: &pointer
        ) == kCMBlockBufferNoErr, let pointer else {
            return
        }

        pointer.withMemoryRebound(to: Int16.self, capacity: length / 2) { samples in
            for index in 0..<(length / 2) {
                each(samples[index])
            }
        }
    }

    private static func resample(_ peaks: [Float], count: Int) -> [Float] {
        guard !peaks.isEmpty, count > 0 else {
            return []
        }

        let step = Float(peaks.count) / Float(count)
        let values = (0..<count).map { index in
            let start = Int(Float(index) * step)
            let end = max(start + 1, min(peaks.count, Int(Float(index + 1) * step)))

            return peaks[start..<end].max() ?? 0
        }
        let top = max(values.max() ?? 1, 0.01)

        return values.map { value in
            value / top
        }
    }
}
