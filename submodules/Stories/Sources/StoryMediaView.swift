import AVFoundation
import UIKit

@MainActor
final class StoryMediaView: UIView {
    private let imageView = UIImageView()
    private let playerLayer = AVPlayerLayer()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var player: AVPlayer?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var isPaused = false
    private var hasImage = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        addSubview(spinner)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isReady: Bool {
        if let player {
            return player.currentItem?.status == .readyToPlay
        }

        return hasImage
    }

    var videoProgress: CGFloat? {
        guard let item = player?.currentItem else {
            return nil
        }

        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else {
            return 0
        }

        return CGFloat(item.currentTime().seconds / duration)
    }

    func show(_ item: StoryItem) {
        stop()
        generation += 1
        let token = generation
        spinner.startAnimating()
        switch item.media {
        case .image(let load):
            let base = bounds.isEmpty ? CGSize(width: 430, height: 932) : bounds.size
            let scale = traitCollection.displayScale
            let size = CGSize(width: base.width * scale, height: base.height * scale)
            task = Task { [weak self] in
                let image = await load(size)
                guard let self, self.generation == token else {
                    return
                }

                self.imageView.image = image
                self.hasImage = image != nil
                self.spinner.stopAnimating()
            }
        case .video(let url):
            let player = AVPlayer(url: url)
            player.preventsDisplaySleepDuringVideoPlayback = true
            playerLayer.player = player
            self.player = player
            if !isPaused {
                player.play()
            }
        }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            player?.pause()
        } else {
            player?.play()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        player?.pause()
        player = nil
        playerLayer.player = nil
        imageView.image = nil
        hasImage = false
    }

    func update() {
        if isReady, spinner.isAnimating {
            spinner.stopAnimating()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}
