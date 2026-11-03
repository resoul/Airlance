import AVFoundation
import Haptics
import Subtitles
import UIKit

final class StoryEditorView: UIView, UIGestureRecognizerDelegate {
    enum Mode {
        case idle
        case draw
        case adjust
        case trim
        case sound
    }

    var onClose: (@MainActor () -> Void)?
    var onPublish: (@MainActor (StoryAudience) -> Void)?
    var onSubtitles: (@MainActor () -> Void)?
    var onCutout: (@MainActor () -> Void)?
    var onPlaceSearch: (@MainActor (String) -> Void)?
    var onPickTrack: (@MainActor () -> Void)?
    var onRecordVoice: (@MainActor () -> Void)?
    var mentionPeers: [StoryMentionPeer] = []

    let strings: StoryStudioStrings
    let media: StudioMedia
    let canvas = StoryCanvasView()
    let palette = StoryPalette()
    let brushBar: StoryBrushBar
    let closeButton = UIButton(type: .system)
    let textButton = UIButton(type: .system)
    let drawButton = UIButton(type: .system)
    let stickerButton = UIButton(type: .system)
    let adjustButton = UIButton(type: .system)
    let soundButton = UIButton(type: .system)
    let extraButton = UIButton(type: .system)
    let undoButton = UIButton(type: .system)
    let doneButton = UIButton(type: .system)
    let audienceButton = UIButton(type: .system)
    let publishButton = UIButton(type: .system)
    let spinner = UIActivityIndicatorView(style: .medium)
    let extraSpinner = UIActivityIndicatorView(style: .medium)
    let subtitleView = SubtitleView()
    let subtitleButton = UIButton(type: .system)
    let subtitleSpinner = UIActivityIndicatorView(style: .medium)
    let mediaView = UIView()
    let imageView = UIImageView()
    let playerLayer = AVPlayerLayer()
    var mode = Mode.idle
    var audience = StoryAudience.everyone
    var settings = StoryPublishSettings()
    var publishSheet: StoryPublishSheet?
    var adjustments = StoryAdjustments()
    var mediaTransform = StoryMediaTransform()
    var trim: StoryTrim?
    var coverTime: TimeInterval = 0
    var sound = StorySound()
    var videoDuration = StorySound.photoDuration
    var soundPanel: StorySoundPanel?
    var trackPlayer: AVPlayer?
    var voicePlayer: AVPlayer?
    var soundClock: Timer?
    var clockStart = Date()
    var lastStoryTime: TimeInterval = 0
    var recorder: AVAudioRecorder?
    var isHoldingRecord = false
    var textEditor: StoryTextEditor?
    var adjustPanel: StoryAdjustPanel?
    var trimView: StoryTrimView?
    var stickerPicker: StoryStickerPicker?
    var widgetForm: StoryWidgetForm?
    var timeObserver: Any?
    var adjustTask: Task<Void, Never>?
    var videoComposition: AVVideoComposition?
    private(set) var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    init(media: StudioMedia, strings: StoryStudioStrings, draft: StoryDraft) {
        self.strings = strings
        self.media = media
        brushBar = StoryBrushBar(strings: strings)
        super.init(frame: .zero)
        backgroundColor = .black
        adjustments = draft.adjustments
        mediaTransform = draft.mediaTransform
        trim = draft.trim
        coverTime = draft.coverTime
        sound = draft.sound
        audience = draft.audience
        settings = draft.settings
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = media.preview
        playerLayer.videoGravity = .resizeAspectFill
        mediaView.isUserInteractionEnabled = false
        mediaView.addSubview(imageView)
        mediaView.layer.addSublayer(playerLayer)
        addSubview(mediaView)
        if case .video(let url, _) = media {
            restartPlayer()
            loadDuration(of: url)
        }
        bindCanvas()
        canvas.load(draft.entities)
        palette.onSelect = { [weak self] color in
            self?.canvas.color = color
        }
        brushBar.onSelect = { [weak self] brush in
            self?.canvas.brush = brush
        }
        addSubview(canvas)
        addSubview(subtitleView)
        setUpTools()
        setUpSubtitles(isVideo: player != nil)
        setUpMediaGestures()
        applyAdjustments()
        applySound()
        updateTools()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var overlay: UIImage? {
        canvas.render(width: StoryExport.width)
    }

    func restartPlayer() {
        guard case .video(let url, _) = media else {
            return
        }

        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        let player = AVQueuePlayer()
        let item = AVPlayerItem(url: url)
        item.videoComposition = videoComposition
        let range = trim.map { trim in
            CMTimeRange(
                start: CMTime(seconds: trim.start, preferredTimescale: 600),
                end: CMTime(seconds: trim.end, preferredTimescale: 600)
            )
        } ?? .invalid
        looper = AVPlayerLooper(player: player, templateItem: item, timeRange: range)
        playerLayer.player = player
        player.volume = recorder == nil ? sound.originalVolume : 0
        player.play()
        self.player = player
        lastStoryTime = .greatestFiniteMagnitude
        if subtitleButton.superview != nil {
            observeTime()
        }
    }

    func stopVideo() {
        stopSound()
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        playerLayer.player = nil
        looper = nil
        player = nil
    }

    func setPublishing(_ isPublishing: Bool) {
        publishButton.isEnabled = !isPublishing
        closeButton.isEnabled = !isPublishing
        publishButton.setTitle(isPublishing ? nil : strings.publish, for: .normal)
        if isPublishing {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mediaView.transform = .identity
        mediaView.frame = bounds
        imageView.frame = mediaView.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = mediaView.bounds
        CATransaction.commit()
        mediaView.transform = mediaTransform.affine(in: bounds.size)
        canvas.frame = bounds
        subtitleView.frame = bounds
        textEditor?.frame = bounds
        stickerPicker?.frame = bounds
        widgetForm?.frame = bounds
        publishSheet?.frame = bounds
        layoutTools()
    }

    private func loadDuration(of url: URL) {
        Task { [weak self] in
            guard let duration = try? await AVURLAsset(url: url).load(.duration).seconds, duration > 0 else {
                return
            }

            self?.videoDuration = duration
        }
    }

    private func bindCanvas() {
        canvas.onEditText = { [weak self] id in
            self?.editText(id)
        }
        canvas.onChange = { [weak self] _ in
            self?.updateTools()
        }
        canvas.onDragging = { [weak self] isDragging in
            self?.setDragging(isDragging)
        }
    }

    func editText(_ id: UUID?) {
        guard textEditor == nil else {
            return
        }

        textEditor = canvas.editText(id, in: self, color: palette.selected, doneTitle: strings.done) { [weak self] in
            self?.textEditor = nil
        }
    }
}
