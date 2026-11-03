import AVFoundation
import Haptics
import Subtitles
import UIKit

final class CameraReviewView: UIView {
    private static let thumb: CGFloat = 52

    var onRetake: (@MainActor () -> Void)?
    var onMore: (@MainActor () -> Void)?
    var onSend: (@MainActor (String) -> Void)?
    var onSelect: (@MainActor (Int) -> Void)?
    var onTool: (@MainActor () -> Void)?

    let toolButton = UIButton(type: .system)
    let toolSpinner = UIActivityIndicatorView(style: .medium)
    let subtitleView = SubtitleView()
    let playerLayer = AVPlayerLayer()
    let sendButton = UIButton(type: .system)
    var timeObserver: Any?
    var toolStrings = (edit: "", subtitles: "")
    private let imageView = UIImageView()
    private let retakeButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private let strip = UIScrollView()
    private let captionBar = UIView()
    private let field = UITextField()
    private let count = UILabel()
    var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var thumbs: [UIButton] = []

    init(presentation: PresentationData) {
        super.init(frame: .zero)
        backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        playerLayer.videoGravity = .resizeAspect
        addSubview(imageView)
        layer.addSublayer(playerLayer)
        addSubview(subtitleView)
        setUpButtons(presentation)
        setUpTool(presentation.strings)
        setUpCaption(presentation)
        strip.showsHorizontalScrollIndicator = false
        addSubview(strip)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ items: [CameraItem], index: Int, subtitles: Subtitles? = nil) {
        let item = items[index]
        imageView.image = item.preview
        stopVideo()
        if case .video(let url, _) = item {
            let player = AVQueuePlayer()
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            playerLayer.player = player
            player.play()
            self.player = player
            observeTime()
        }
        setTool(for: item, subtitles: subtitles)
        count.text = items.count > 1 ? "\(items.count)" : nil
        count.isHidden = items.count < 2
        rebuildStrip(items, selected: index)
        setNeedsLayout()
    }

    func stopVideo() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
        looper = nil
        playerLayer.player = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let safe = safeAreaInsets
        imageView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
        let top = max(safe.top, 16) + 6
        let retakeWidth = ceil(retakeButton.sizeThatFits(bounds.size).width) + 28
        retakeButton.frame = CGRect(x: 16, y: top, width: retakeWidth, height: 40)
        let moreWidth = ceil(moreButton.sizeThatFits(bounds.size).width) + 28
        moreButton.frame = CGRect(x: bounds.width - 16 - moreWidth, y: top, width: moreWidth, height: 40)
        for button in [retakeButton, moreButton] {
            button.layer.cornerRadius = 20
        }
        layoutTool(top: top)
        let stripWidth = min(bounds.width - 32, CGFloat(thumbs.count) * (Self.thumb + 6))
        strip.frame = CGRect(
            x: (bounds.width - stripWidth) / 2,
            y: captionBar.frame.minY - Self.thumb - 12,
            width: stripWidth,
            height: Self.thumb
        )
        for (index, thumb) in thumbs.enumerated() {
            thumb.frame = CGRect(x: CGFloat(index) * (Self.thumb + 6), y: 0, width: Self.thumb, height: Self.thumb)
        }
        strip.contentSize = CGSize(width: CGFloat(thumbs.count) * (Self.thumb + 6) - 6, height: Self.thumb)
    }

    private func setUpButtons(_ presentation: PresentationData) {
        let strings = presentation.strings
        for (button, title, symbol) in [
            (retakeButton, strings.cameraRetake, "arrow.counterclockwise"),
            (moreButton, strings.cameraMore, "plus"),
        ] {
            var configuration = UIButton.Configuration.plain()
            configuration.title = title
            configuration.image = UIImage(systemName: symbol)
            configuration.imagePadding = 6
            configuration.baseForegroundColor = .white
            button.configuration = configuration
            button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            addSubview(button)
        }
        retakeButton.addAction(UIAction { [weak self] _ in
            self?.onRetake?()
        }, for: .touchUpInside)
        moreButton.addAction(UIAction { [weak self] _ in
            self?.onMore?()
        }, for: .touchUpInside)
    }

    private func setUpCaption(_ presentation: PresentationData) {
        let theme = presentation.theme
        captionBar.backgroundColor = UIColor(white: 0.12, alpha: 0.92)
        captionBar.layer.cornerRadius = 24
        captionBar.layer.cornerCurve = .continuous
        captionBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(captionBar)
        field.font = theme.fonts.body
        field.textColor = .white
        field.tintColor = theme.colors.accent
        field.attributedPlaceholder = NSAttributedString(
            string: presentation.strings.cameraCaption,
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.5)]
        )
        field.returnKeyType = .send
        field.addAction(UIAction { [weak self] _ in
            self?.send()
        }, for: .editingDidEndOnExit)
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        sendButton.setImage(UIImage(systemName: "arrow.up", withConfiguration: configuration), for: .normal)
        sendButton.tintColor = theme.colors.onAccent
        sendButton.backgroundColor = theme.colors.accent
        sendButton.layer.cornerRadius = 18
        sendButton.accessibilityLabel = presentation.strings.chatSend
        sendButton.addAction(UIAction { [weak self] _ in
            self?.send()
        }, for: .touchUpInside)
        count.font = .systemFont(ofSize: 12, weight: .bold)
        count.textColor = theme.colors.accent
        count.backgroundColor = .white
        count.textAlignment = .center
        count.layer.cornerRadius = 9
        count.clipsToBounds = true
        for view in [field, sendButton, count] {
            view.translatesAutoresizingMaskIntoConstraints = false
            captionBar.addSubview(view)
        }
        constrainCaption()
    }

    private func constrainCaption() {
        let keyboard = captionBar.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor, constant: -10)
        keyboard.priority = .defaultHigh
        NSLayoutConstraint.activate([
            keyboard,
            captionBar.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),
            captionBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            captionBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            captionBar.heightAnchor.constraint(equalToConstant: 48),
            field.leadingAnchor.constraint(equalTo: captionBar.leadingAnchor, constant: 18),
            field.centerYAnchor.constraint(equalTo: captionBar.centerYAnchor),
            field.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            sendButton.trailingAnchor.constraint(equalTo: captionBar.trailingAnchor, constant: -6),
            sendButton.centerYAnchor.constraint(equalTo: captionBar.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
            count.centerXAnchor.constraint(equalTo: sendButton.trailingAnchor, constant: -4),
            count.centerYAnchor.constraint(equalTo: sendButton.topAnchor, constant: 4),
            count.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            count.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    private func rebuildStrip(_ items: [CameraItem], selected: Int) {
        thumbs.forEach { thumb in
            thumb.removeFromSuperview()
        }
        thumbs = items.count < 2 ? [] : items.enumerated().map { index, item in
            let button = UIButton(type: .custom)
            button.setImage(item.preview, for: .normal)
            button.imageView?.contentMode = .scaleAspectFill
            button.clipsToBounds = true
            button.layer.cornerRadius = 8
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.borderWidth = index == selected ? 2.5 : 0
            button.addAction(UIAction { [weak self] _ in
                Haptics.play(.selection)
                self?.onSelect?(index)
            }, for: .touchUpInside)
            strip.addSubview(button)

            return button
        }
    }

    private func send() {
        stopVideo()
        onSend?(field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
}
