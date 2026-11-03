import AVFoundation
import ChatHistory
import LiquidUI
import MediaLoader
import MusicPlayer
import UIKit

@MainActor
final class VideoNoteView: UIView {
    private static weak var playing: VideoNoteView?

    let note: MessageVideoNote
    private let container = UIView()
    private let poster = UIImageView()
    private let playerLayer = AVPlayerLayer()
    private let shape = CAShapeLayer()
    private let ring = CAShapeLayer()
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var phase: CGFloat = 0
    private(set) var isPlaying = false
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.step(deltaTime)
    }

    init(note: MessageVideoNote, accent: UIColor) {
        self.note = note
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        poster.contentMode = .scaleAspectFill
        container.addSubview(poster)
        playerLayer.videoGravity = .resizeAspectFill
        container.layer.addSublayer(playerLayer)
        container.layer.mask = shape
        addSubview(container)
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        ring.lineWidth = 3
        ring.lineCap = .round
        ring.strokeEnd = 0
        layer.addSublayer(ring)
        loadPoster()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        container.frame = bounds
        poster.frame = bounds
        playerLayer.frame = bounds
        updateShape()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            driver.stop()
            stop()

            return
        }

        driver.start()
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func loadPoster() {
        let request = MediaImageRequest(
            source: note.source,
            size: VideoNoteBody.size(for: note.style),
            scale: UIScreen.main.scale,
            corners: .zero
        )
        Task { [weak self] in
            let image = await MediaImageLoader.shared.image(for: request)
            self?.poster.image = image
        }
    }

    private func makePlayer() -> AVPlayer? {
        guard let url = note.source.url else {
            return nil
        }

        let player = AVPlayer(url: url)
        playerLayer.player = player
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.finished()
            }
        }
        self.player = player

        return player
    }

    private func play() {
        guard let player = player ?? makePlayer() else {
            return
        }

        Self.playing?.pause()
        Self.playing = self
        AudioPlayer.shared.pause()
        AudioSessionQueue.run {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        player.isMuted = false
        player.play()
        isPlaying = true
    }

    private func pause() {
        player?.pause()
        isPlaying = false
    }

    private func finished() {
        isPlaying = false
        ring.strokeEnd = 0
        player?.seek(to: .zero)
    }

    private func stop() {
        pause()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player = nil
        playerLayer.player = nil
    }

    private func step(_ deltaTime: CFTimeInterval) {
        phase += CGFloat(deltaTime) * (isPlaying ? 2.4 : 0.8)
        if let player, note.duration > 0 {
            let progress = CMTimeGetSeconds(player.currentTime()) / note.duration
            ring.strokeEnd = isPlaying ? CGFloat(min(1, max(0, progress))) : ring.strokeEnd
        }
        if note.style == .blob {
            updateShape()
        }
    }

    private var level: CGFloat {
        guard isPlaying, let player, note.duration > 0 else {
            return 0.15
        }

        return VideoNoteLevels.level(note.levels, at: CMTimeGetSeconds(player.currentTime()) / note.duration)
    }

    private func updateShape() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = VideoNoteBody.cornerRadius(for: note.style, size: bounds.size)
        switch note.style {
        case .blob:
            shape.path = BlobShape.path(in: bounds, phase: phase, level: level)
        case .reaction:
            shape.path = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        }
        ring.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), cornerRadius: max(0, radius - 3)).cgPath
        ring.isHidden = note.style == .blob
        CATransaction.commit()
    }
}
