import UIKit

public struct AudioPanelStyle {
    public var background: UIColor
    public var primary: UIColor
    public var secondary: UIColor
    public var accent: UIColor
    public var separator: UIColor
    public var titleFont: UIFont
    public var subtitleFont: UIFont

    public init(
        background: UIColor,
        primary: UIColor,
        secondary: UIColor,
        accent: UIColor,
        separator: UIColor,
        titleFont: UIFont,
        subtitleFont: UIFont
    ) {
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.separator = separator
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
    }
}

public final class AudioPanelView: UIView {
    public static let height: CGFloat = 44

    public var onOpen: (@MainActor () -> Void)?
    public var showsSeparator = true {
        didSet {
            setNeedsLayout()
        }
    }
    private let player: AudioPlayer
    private let playButton = UIButton(type: .system)
    private let rateButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let texts = UIView()
    private let progress = UIView()
    private let separator = UIView()
    private var shown: PlaybackState?

    public init(player: AudioPlayer = .shared) {
        self.player = player
        super.init(frame: .zero)
        for view in [texts, playButton, rateButton, closeButton, progress, separator] {
            addSubview(view)
        }
        texts.addSubview(titleLabel)
        texts.addSubview(subtitleLabel)
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func apply(_ style: AudioPanelStyle) {
        backgroundColor = style.background
        separator.backgroundColor = style.separator
        progress.backgroundColor = style.accent
        titleLabel.font = style.titleFont
        titleLabel.textColor = style.primary
        subtitleLabel.font = style.subtitleFont
        subtitleLabel.textColor = style.secondary
        for button in [playButton, closeButton] {
            button.tintColor = style.primary
        }
        rateButton.tintColor = style.accent
        rateButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        shown = nil
        update(player.state)
    }

    public func update(_ state: PlaybackState) {
        var visible = state
        visible.position = shown?.position ?? 0
        guard visible != shown else {
            shown = state
            layoutProgress(state.progress)

            return
        }

        shown = state
        let symbol = state.isPlaying ? "pause.fill" : "play.fill"
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        playButton.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        rateButton.setTitle(state.rate.title, for: .normal)
        let rateAlpha: CGFloat = state.rate == .normal ? 0.55 : 1
        rateButton.alpha = rateAlpha
        titleLabel.text = state.track?.title
        subtitleLabel.text = state.track?.artist
        subtitleLabel.isHidden = (state.track?.artist ?? "").isEmpty
        layoutProgress(state.progress)
        setNeedsLayout()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let height = bounds.height
        playButton.frame = CGRect(x: 4, y: 0, width: 44, height: height)
        closeButton.frame = CGRect(x: bounds.width - 48, y: 0, width: 44, height: height)
        rateButton.frame = CGRect(x: closeButton.frame.minX - 44, y: 0, width: 44, height: height)
        let textX = playButton.frame.maxX + 4
        texts.frame = CGRect(x: textX, y: 0, width: max(1, rateButton.frame.minX - textX - 4), height: height)
        let titleHeight = ceil(titleLabel.font.lineHeight)
        let subtitleHeight = subtitleLabel.isHidden ? 0 : ceil(subtitleLabel.font.lineHeight)
        let top = (height - titleHeight - subtitleHeight) / 2
        titleLabel.frame = CGRect(x: 0, y: top, width: texts.bounds.width, height: titleHeight)
        subtitleLabel.frame = CGRect(x: 0, y: titleLabel.frame.maxY, width: texts.bounds.width, height: subtitleHeight)
        let line = 1 / max(traitCollection.displayScale, 1)
        separator.frame = CGRect(x: 0, y: height - line, width: bounds.width, height: line)
        separator.isHidden = !showsSeparator
        layoutProgress(player.state.progress)
    }

    private func layoutProgress(_ value: Double) {
        progress.frame = CGRect(x: 0, y: bounds.height - 2, width: bounds.width * CGFloat(value), height: 2)
    }

    private func setupActions() {
        let player = player
        playButton.addAction(UIAction { _ in
            player.toggle()
        }, for: .touchUpInside)
        closeButton.addAction(UIAction { _ in
            player.stop()
        }, for: .touchUpInside)
        rateButton.addAction(UIAction { _ in
            player.setRate(player.state.rate.next)
        }, for: .touchUpInside)
        texts.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(opened)))
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            texts.addGestureRecognizer(swipe)
        }
    }

    @objc private func opened() {
        onOpen?()
    }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        gesture.direction == .left ? player.next() : player.previous()
    }
}
