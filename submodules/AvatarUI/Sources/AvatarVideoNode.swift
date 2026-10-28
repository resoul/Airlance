@preconcurrency import AsyncDisplayKit
import AVFoundation
import UIKit

@MainActor
final class AvatarVideoNode: ASDisplayNode {
    var onReady: ((Bool) -> Void)?
    var onFailure: (() -> Void)?

    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var readyObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var loading: Task<Void, Never>?
    private var source: Source?
    private var generation = 0
    private var allowed = false
    private(set) var failed = false

    override func didLoad() {
        super.didLoad()
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.masksToBounds = true
        layer.addSublayer(playerLayer)
        let owner = WeakOwner(self)
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { @Sendable layer, _ in
            let ready = layer.isReadyForDisplay
            Task { @MainActor in
                owner.value?.onReady?(ready)
            }
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        playerLayer.cornerRadius = min(bounds.width, bounds.height) / 2
        CATransaction.commit()
    }

    func setSource(key: String, url: URL, start: Double) {
        let source = Source(key: key, url: url, start: start)
        guard self.source != source else {
            return
        }

        reset()
        self.source = source
    }

    func setAllowed(_ allowed: Bool) {
        self.allowed = allowed
        guard allowed else {
            player?.pause()
            if loading != nil {
                release()
            }

            return
        }

        if let player {
            onReady?(playerLayer.isReadyForDisplay)
            player.play()
        } else if loading == nil, !failed {
            load()
        }
    }

    func reset() {
        release()
        source = nil
        failed = false
    }

    private func load() {
        guard let source else {
            return
        }

        generation += 1
        let token = generation
        loading = Task { [weak self] in
            do {
                let file = try await AvatarFileCache.shared.fileURL(for: source.url, key: source.key)
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try await Self.prepare(file)
                }.value
                guard let self, self.generation == token, self.allowed else {
                    return
                }

                self.start(prepared, at: source.start)
            } catch {
                guard let self, self.generation == token else {
                    return
                }

                self.fail()
            }
        }
    }

    private func start(_ prepared: PreparedVideo, at start: Double) {
        loading = nil
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: prepared.asset))
        let owner = WeakOwner(self)
        statusObservation = looper.observe(\.status, options: [.new]) { @Sendable looper, _ in
            guard looper.status == .failed else {
                return
            }

            Task { @MainActor in
                owner.value?.fail()
            }
        }
        self.player = player
        self.looper = looper
        playerLayer.player = player

        let offset = min(start, max(0, prepared.duration - 0.05))
        guard offset > 0 else {
            player.play()

            return
        }

        let token = generation
        let time = CMTime(seconds: offset, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { @Sendable _ in
            Task { @MainActor in
                guard let node = owner.value, node.generation == token, node.allowed else {
                    return
                }

                node.player?.play()
            }
        }
    }

    private func fail() {
        failed = true
        release()
        onFailure?()
    }

    private func release() {
        generation += 1
        loading?.cancel()
        loading = nil
        statusObservation = nil
        looper?.disableLooping()
        looper = nil
        player?.pause()
        player?.removeAllItems()
        player = nil
        playerLayer.player = nil
        onReady?(false)
    }

    nonisolated private static func prepare(_ url: URL) async throws -> PreparedVideo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard duration.isFinite, duration > 0, duration <= AvatarVideo.maximumDuration + 0.05,
              let track = tracks.first else {
            throw URLError(.cannotDecodeContentData)
        }

        let transform = try await track.load(.preferredTransform)
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw URLError(.cannotDecodeContentData)
        }

        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
        try videoTrack.insertTimeRange(range, of: track, at: .zero)
        videoTrack.preferredTransform = transform

        return PreparedVideo(asset: composition, duration: duration)
    }
}

private struct Source: Equatable {
    let key: String
    let url: URL
    let start: Double
}

private struct PreparedVideo: @unchecked Sendable {
    let asset: AVAsset
    let duration: Double
}

private final class WeakOwner: @unchecked Sendable {
    weak var value: AvatarVideoNode?

    init(_ value: AvatarVideoNode) {
        self.value = value
    }
}
