import AvatarUI
import AVFoundation
import Haptics
import MediaStore
import UIKit

private final class AvatarPlayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer? {
        layer as? AVPlayerLayer
    }
}

final class AvatarVideoEditorController: UIViewController {
    private static let thumbnailCount = 8
    private static let trimHeight: CGFloat = 56

    var onDone: (@MainActor (ProcessedAvatarVideo) -> Void)?

    private let source: URL
    private let removesSource: Bool
    private let framing: CGSize?
    private let store: MediaStore
    private let presentationData: PresentationData
    private let player: AVPlayer
    private let playerClip = UIView()
    private let playerView = AvatarPlayerView()
    private var fraction: CGFloat = 1
    private let trim: AvatarTrimView
    private let chrome: AvatarEditorChrome
    private var timeObserver: Any?

    init(source: URL, removesSource: Bool, framing: CGSize?, store: MediaStore, presentation: PresentationData) {
        self.framing = framing
        self.source = source
        self.removesSource = removesSource
        self.store = store
        presentationData = presentation
        player = AVPlayer(url: source)
        trim = AvatarTrimView(accent: presentation.theme.colors.accent)
        chrome = AvatarEditorChrome(hint: "", presentation: presentation)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        player.isMuted = true
        playerView.playerLayer?.player = player
        playerView.playerLayer?.videoGravity = .resizeAspectFill
        playerClip.clipsToBounds = true
        playerClip.addSubview(playerView)
        view.addSubview(playerClip)
        view.addSubview(trim)
        view.addSubview(chrome)
        chrome.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }
        chrome.onDone = { [weak self] in
            self?.finish()
        }
        trim.onChange = { [weak self] range, edge in
            self?.trimChanged(range, edge: edge)
        }
        trim.onEnd = { [weak self] in
            self?.restart()
        }
        Task { [weak self] in
            await self?.loadVideo()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds
        let side = bounds.width - 16
        let bottom = view.safeAreaInsets.bottom
        playerClip.frame = CGRect(x: 8, y: (bounds.height - side) / 2 - 40, width: side, height: side)
        playerClip.layer.cornerRadius = side / 2
        let zoomed = side / fraction
        playerView.frame = CGRect(x: (side - zoomed) / 2, y: (side - zoomed) / 2, width: zoomed, height: zoomed)
        chrome.frame = CGRect(x: 16, y: bounds.height - bottom - 68, width: bounds.width - 32, height: 52)
        trim.frame = CGRect(
            x: 16,
            y: chrome.frame.minY - Self.trimHeight - 20,
            width: bounds.width - 32,
            height: Self.trimHeight
        )
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if removesSource, isBeingDismissed {
            try? FileManager.default.removeItem(at: source)
        }
    }

    private func loadVideo() async {
        let asset = AVURLAsset(url: source)
        let length = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let natural = try? await track.load(.naturalSize),
           let transform = try? await track.load(.preferredTransform) {
            let shown = CGRect(origin: .zero, size: natural).applying(transform).size
            fraction = AvatarFraming.fraction(content: shown, preview: framing)
            view.setNeedsLayout()
        }
        trim.configure(duration: length, maximumLength: AvatarVideo.maximumDuration)
        updateHint()
        observeTime()
        player.play()
        trim.setThumbnails(await Self.thumbnails(of: asset, length: length))
    }

    private func observeTime() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.timeChanged(time)
            }
        }
    }

    private func timeChanged(_ time: CMTime) {
        let seconds = CMTimeGetSeconds(time)
        trim.setPlayhead(seconds)
        if seconds >= trim.range.end {
            restart()
        }
    }

    private func trimChanged(_ range: AvatarTrimRange, edge: AvatarTrimView.Edge) {
        player.pause()
        let time = edge == .end ? range.end : range.start
        player.seek(
            to: CMTime(seconds: time, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        updateHint()
    }

    private func restart() {
        player.seek(
            to: CMTime(seconds: trim.range.start, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        player.play()
    }

    private func updateHint() {
        let length = Int((trim.range.end - trim.range.start).rounded())
        chrome.setHint(presentationData.strings.avatarEditorTrimHint(String(length)))
    }

    private func finish() {
        player.pause()
        chrome.setBusy(true)
        let range = trim.range
        Task { [weak self] in
            guard let self else {
                return
            }

            let processed = await AvatarVideoProcessor.process(
                self.source,
                range: range,
                framing: self.framing,
                store: self.store
            )
            self.chrome.setBusy(false)
            guard let processed else {
                Haptics.play(.warning)
                self.player.play()

                return
            }

            Haptics.play(.success)
            self.onDone?(processed)
            self.dismiss(animated: true)
        }
    }

    private static func thumbnails(of asset: AVURLAsset, length: Double) async -> [UIImage] {
        guard length > 0 else {
            return []
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        var images: [UIImage] = []
        for index in 0..<thumbnailCount {
            let seconds = length * Double(index) / Double(thumbnailCount)
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            let frame = await withCheckedContinuation { (continuation: CheckedContinuation<SendableImage, Never>) in
                generator.generateCGImageAsynchronously(for: time) { image, _, _ in
                    continuation.resume(returning: SendableImage(image: image.map(UIImage.init(cgImage:))))
                }
            }
            if let image = frame.image {
                images.append(image)
            }
        }

        return images
    }
}
