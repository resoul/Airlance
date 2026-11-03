import AVFoundation
import Observers
import UIKit

@MainActor
public final class AudioPlayer {
    public static let shared = AudioPlayer()

    public internal(set) var state = PlaybackState()
    public internal(set) var artwork: UIImage?
    let player = AVPlayer()
    var trackQueue = AudioQueue()
    var wasInterrupted = false
    var sessionTokens: [NSObjectProtocol] = []
    private let observers = ObserverList<PlaybackState>()
    private var timeObserver: Any?
    private var endToken: NSObjectProtocol?

    private init() {
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .pause
        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        observeSession()
        setupRemoteCommands()
    }

    public func observe(_ observer: @escaping @MainActor @Sendable (PlaybackState) -> Void) -> ObservationToken {
        observers.add(observer)
    }

    public func play(_ tracks: [AudioTrack], startAt id: String) {
        let start = tracks.firstIndex { track in
            track.id == id
        }
        guard let start else {
            return
        }

        let track = tracks[start]
        guard !state.isCurrent(track.id, in: track.groupID) else {
            toggle()

            return
        }

        trackQueue.load(tracks, start: start, order: track.kind == .voice ? .regular : state.order)
        startCurrent()
    }

    public var queue: [AudioTrack] {
        trackQueue.ordered
    }

    public func jump(to id: String) {
        let position = trackQueue.ordered.firstIndex { track in
            track.id == id
        }
        guard let position, trackQueue.jump(to: position) else {
            return
        }

        startCurrent()
    }

    public func toggle() {
        state.isPlaying ? pause() : resume()
    }

    public func pause() {
        guard state.isPlaying else {
            return
        }

        player.pause()
        state.isPlaying = false
        changed()
    }

    public func resume() {
        guard state.track != nil else {
            return
        }

        state.isPlaying = true
        changed()
        activateSession { [weak self] in
            self?.playIfNeeded()
        }
    }

    public func next() {
        guard trackQueue.advance(looping: looping) else {
            return
        }

        startCurrent()
    }

    public func previous() {
        guard state.position < 3, trackQueue.back() else {
            seek(to: 0)

            return
        }

        startCurrent()
    }

    public func seek(to time: TimeInterval) {
        let target = CMTime(seconds: max(0, time), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        state.position = max(0, time)
        changed()
    }

    public func setRate(_ rate: PlaybackRate) {
        state.rate = rate
        if state.isPlaying {
            player.rate = Float(rate.rawValue)
        }
        changed()
    }

    public func setOrder(_ order: PlaybackOrder) {
        state.order = order
        if state.track?.kind == .music {
            trackQueue.arrange(order)
        }
        changed()
    }

    public func setLooping(_ looping: PlaybackLooping) {
        state.looping = looping
        changed()
    }

    public func stop() {
        guard state.track != nil else {
            return
        }

        player.pause()
        player.replaceCurrentItem(with: nil)
        endToken = nil
        trackQueue.clear()
        artwork = nil
        var next = PlaybackState()
        next.rate = state.rate
        next.order = state.order
        next.looping = state.looping
        state = next
        deactivateSession()
        changed()
    }

    var looping: PlaybackLooping {
        state.track?.kind == .voice ? .none : state.looping
    }

    func changed() {
        state.hasPrevious = trackQueue.hasPrevious
        state.hasNext = trackQueue.hasNext(looping: looping)
        observers.notify(state)
        updateNowPlaying()
    }

    private func startCurrent() {
        guard let track = trackQueue.current else {
            stop()

            return
        }

        let item = AVPlayerItem(url: track.url)
        endToken = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.finished()
            }
        }
        player.replaceCurrentItem(with: item)
        state.track = track
        state.position = 0
        state.duration = 0
        artwork = nil
        state.isPlaying = true
        changed()
        activateSession { [weak self] in
            self?.playIfNeeded()
        }
        loadMetadata(track)
    }

    private func playIfNeeded() {
        guard state.isPlaying, player.currentItem != nil else {
            return
        }

        player.playImmediately(atRate: Float(state.rate.rawValue))
    }

    private func finished() {
        if looping == .one {
            seek(to: 0)
            player.playImmediately(atRate: Float(state.rate.rawValue))

            return
        }

        guard trackQueue.advance(looping: looping) else {
            ended()

            return
        }

        startCurrent()
    }

    private func ended() {
        player.pause()
        state.isPlaying = false
        seek(to: 0)
        deactivateSession()
    }

    private func tick() {
        guard state.track != nil else {
            return
        }

        let position = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? 0
        state.position = position.isFinite ? position : 0
        if duration.isFinite, duration > 0 {
            state.duration = duration
        }
        observers.notify(state)
    }

    private func loadMetadata(_ track: AudioTrack) {
        let url = track.url
        Task { [weak self] in
            let metadata = await TrackMetadata.load(url)
            self?.apply(metadata, to: track)
        }
    }

    private func apply(_ metadata: TrackMetadata, to track: AudioTrack) {
        guard state.isCurrent(track.id, in: track.groupID) else {
            return
        }

        if track.kind == .music {
            var updated = track
            updated.title = metadata.title ?? track.title
            updated.artist = metadata.artist ?? track.artist
            trackQueue.update(updated)
            state.track = updated
            artwork = metadata.artwork.flatMap(UIImage.init(data:))
        }
        if state.duration <= 0, metadata.duration > 0 {
            state.duration = metadata.duration
        }
        changed()
    }
}
