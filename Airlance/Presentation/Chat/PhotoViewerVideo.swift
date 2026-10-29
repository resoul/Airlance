import AVFoundation
import UIKit

final class VideoPlayerView: UIView {
    var onProgress: (@MainActor (VideoPlayerView) -> Void)?

    private let player: AVPlayer
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer? {
        layer as? AVPlayerLayer
    }

    var isPlaying: Bool {
        player.rate > 0
    }

    var currentTime: TimeInterval {
        Self.seconds(player.currentTime())
    }

    var duration: TimeInterval {
        Self.seconds(player.currentItem?.duration ?? .zero)
    }

    init(url: URL) {
        player = AVPlayer(url: url)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        playerLayer?.player = player
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.opacity = 0
        observe()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func play() {
        if duration > 0, currentTime >= duration - 0.05 {
            player.seek(to: .zero)
        }
        player.play()
        onProgress?(self)
    }

    func pause() {
        player.pause()
        onProgress?(self)
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func seek(to fraction: CGFloat) {
        let time = CMTime(seconds: duration * Double(min(max(fraction, 0), 1)), preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        onProgress?(self)
    }

    func stop() {
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func observe() {
        let interval = CMTime(seconds: 1.0 / 30, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }

                if time.seconds > 0, self.playerLayer?.opacity == 0 {
                    self.playerLayer?.opacity = 1
                }
                self.onProgress?(self)
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pause()
            }
        }
    }

    private static func seconds(_ time: CMTime) -> TimeInterval {
        time.isNumeric ? max(0, time.seconds) : 0
    }
}

final class VideoControlsView: UIView {
    static let height: CGFloat = 52

    var onToggle: (@MainActor () -> Void)?
    var onSeek: (@MainActor (CGFloat) -> Void)?

    private let button = UIButton(type: .system)
    private let elapsed = UILabel()
    private let total = UILabel()
    private let slider = UISlider()
    private var isScrubbing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.4)
        button.tintColor = .white
        button.addAction(
            UIAction { [weak self] _ in
                self?.onToggle?()
            },
            for: .touchUpInside
        )
        addSubview(button)
        for label in [elapsed, total] {
            label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            label.textColor = .white
            addSubview(label)
        }
        total.textAlignment = .right
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.3)
        slider.setThumbImage(Self.thumb(), for: .normal)
        slider.addTarget(self, action: #selector(scrubbed), for: .valueChanged)
        slider.addTarget(self, action: #selector(scrubEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addSubview(slider)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        button.frame = CGRect(x: 8, y: 4, width: 44, height: 44)
        elapsed.frame = CGRect(x: 52, y: 4, width: 44, height: 44)
        total.frame = CGRect(x: bounds.width - 60, y: 4, width: 48, height: 44)
        slider.frame = CGRect(x: 100, y: 4, width: max(0, bounds.width - 168), height: 44)
    }

    func update(current: TimeInterval, duration: TimeInterval, isPlaying: Bool) {
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        let configuration = UIImage.SymbolConfiguration(pointSize: 20)
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        elapsed.text = VideoBadge.text(current)
        total.text = VideoBadge.text(duration)
        if !isScrubbing {
            slider.value = duration > 0 ? Float(current / duration) : 0
        }
    }

    @objc
    private func scrubbed() {
        isScrubbing = true
        onSeek?(CGFloat(slider.value))
    }

    @objc
    private func scrubEnded() {
        isScrubbing = false
    }

    private static func thumb() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 14, height: 14)).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 14, height: 14))
        }
    }
}

extension PhotoViewerView {
    func addVideo(_ url: URL, page: Int, in view: UIView) {
        let player = VideoPlayerView(url: url)
        player.frame = view.bounds
        player.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(player)
        players[page] = player
    }

    func buildControls(safeBottom: CGFloat) {
        let height = VideoControlsView.height + safeBottom
        controls.frame = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
        controls.alpha = 0
        controls.onToggle = { [weak self] in
            self?.currentPlayer?.toggle()
        }
        controls.onSeek = { [weak self] fraction in
            self?.currentPlayer?.seek(to: fraction)
        }
        addSubview(controls)
    }

    var currentPlayer: VideoPlayerView? {
        players[index]
    }

    func activateVideo() {
        for (page, player) in players where page != index {
            player.onProgress = nil
            player.pause()
        }
        guard let player = currentPlayer else {
            return
        }

        player.onProgress = { [weak self] player in
            self?.controls.update(current: player.currentTime, duration: player.duration, isPlaying: player.isPlaying)
        }
        player.play()
    }

    func stopVideos() {
        for player in players.values {
            player.onProgress = nil
            player.stop()
        }
    }

    func setChromeAlpha(_ alpha: CGFloat) {
        topBar.alpha = alpha
        controls.alpha = currentPlayer == nil ? 0 : alpha
    }
}
