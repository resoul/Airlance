import UIKit

final class AudioControlsView: UIView {
    static let height: CGFloat = 276

    private let player: AudioPlayer
    private let artwork = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let scrubber = AudioScrubberView()
    private let elapsed = UILabel()
    private let remaining = UILabel()
    private let orderButton = UIButton(type: .system)
    private let previousButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let loopButton = UIButton(type: .system)
    private let rateButton = UIButton(type: .system)
    private var style: AudioPanelStyle?

    init(player: AudioPlayer) {
        self.player = player
        super.init(frame: .zero)
        let views: [UIView] = [
            artwork, titleLabel, artistLabel, scrubber, elapsed, remaining,
            orderButton, previousButton, playButton, nextButton, loopButton, rateButton,
        ]
        for view in views {
            addSubview(view)
        }
        artwork.contentMode = .center
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = 12
        artwork.layer.cornerCurve = .continuous
        remaining.textAlignment = .right
        rateButton.layer.cornerRadius = 8
        rateButton.layer.borderWidth = 1.5
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ style: AudioPanelStyle) {
        self.style = style
        titleLabel.font = style.titleFont.withSize(19)
        titleLabel.textColor = style.primary
        artistLabel.font = style.subtitleFont.withSize(15)
        artistLabel.textColor = style.secondary
        let digits = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        for label in [elapsed, remaining] {
            label.font = digits
            label.textColor = style.secondary
        }
        scrubber.apply(track: style.separator, fill: style.accent)
        for button in [previousButton, playButton, nextButton] {
            button.tintColor = style.primary
        }
        rateButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        update(player.state)
    }

    func update(_ state: PlaybackState) {
        guard let style else {
            return
        }

        titleLabel.text = state.track?.title
        artistLabel.text = state.track?.artist
        scrubber.set(state.progress)
        elapsed.text = Self.time(state.position)
        remaining.text = "-" + Self.time(max(0, state.duration - state.position))
        updateArtwork(state, style: style)
        updateButtons(state, style: style)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        artwork.frame = CGRect(x: 20, y: 20, width: 64, height: 64)
        let textX = artwork.frame.maxX + 14
        let textWidth = max(1, width - textX - 20)
        titleLabel.frame = CGRect(x: textX, y: 28, width: textWidth, height: 24)
        artistLabel.frame = CGRect(x: textX, y: titleLabel.frame.maxY + 2, width: textWidth, height: 20)
        scrubber.frame = CGRect(x: 20, y: 104, width: width - 40, height: 28)
        elapsed.frame = CGRect(x: 20, y: scrubber.frame.maxY, width: 80, height: 16)
        remaining.frame = CGRect(x: width - 100, y: scrubber.frame.maxY, width: 80, height: 16)
        let buttons = [orderButton, previousButton, playButton, nextButton, loopButton]
        let step = (width - 40) / CGFloat(buttons.count)
        for (index, button) in buttons.enumerated() {
            let size: CGFloat = button === playButton ? 68 : 48
            let centerX = 20 + step * (CGFloat(index) + 0.5)
            button.frame = CGRect(x: centerX - size / 2, y: 196 - size / 2, width: size, height: size)
        }
        rateButton.frame = CGRect(x: (width - 56) / 2, y: 238, width: 56, height: 30)
    }

    private func updateArtwork(_ state: PlaybackState, style: AudioPanelStyle) {
        if let image = player.artwork, state.track?.kind == .music {
            artwork.image = image
            artwork.contentMode = .scaleAspectFill
            artwork.backgroundColor = .clear
        } else {
            let symbol = state.track?.kind == .voice ? "waveform" : "music.note"
            let configuration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
            artwork.image = UIImage(systemName: symbol, withConfiguration: configuration)
            artwork.tintColor = style.accent
            artwork.contentMode = .center
            artwork.backgroundColor = style.accent.withAlphaComponent(0.15)
        }
    }

    private func updateButtons(_ state: PlaybackState, style: AudioPanelStyle) {
        playButton.setImage(Self.symbol(state.isPlaying ? "pause.fill" : "play.fill", size: 34), for: .normal)
        previousButton.setImage(Self.symbol("backward.fill", size: 22), for: .normal)
        nextButton.setImage(Self.symbol("forward.fill", size: 22), for: .normal)
        nextButton.isEnabled = state.hasNext
        let isMusic = state.track?.kind == .music
        orderButton.isHidden = !isMusic
        loopButton.isHidden = !isMusic
        let order = switch state.order {
        case .regular:
            "arrow.down"
        case .reversed:
            "arrow.up"
        case .random:
            "shuffle"
        }
        orderButton.setImage(Self.symbol(order, size: 18), for: .normal)
        orderButton.tintColor = state.order == .regular ? style.secondary : style.accent
        loopButton.setImage(Self.symbol(state.looping == .one ? "repeat.1" : "repeat", size: 18), for: .normal)
        loopButton.tintColor = state.looping == .none ? style.secondary : style.accent
        rateButton.setTitle(state.rate.title, for: .normal)
        let rateColor = state.rate == .normal ? style.secondary : style.accent
        rateButton.tintColor = rateColor
        rateButton.layer.borderColor = rateColor.cgColor
    }

    private func setupActions() {
        let player = player
        let actions: [(UIButton, @MainActor () -> Void)] = [
            (playButton, player.toggle),
            (previousButton, player.previous),
            (nextButton, player.next),
            (orderButton, {
                player.setOrder(player.state.order.next)
            }),
            (loopButton, {
                player.setLooping(player.state.looping.next)
            }),
            (rateButton, {
                player.setRate(player.state.rate.next)
            }),
        ]
        for (button, action) in actions {
            button.addAction(UIAction { _ in
                action()
            }, for: .touchUpInside)
        }
        scrubber.onSeek = { fraction in
            player.seek(to: player.state.duration * fraction)
        }
    }

    private static func symbol(_ name: String, size: CGFloat) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold))
    }

    static func time(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.isFinite ? max(0, seconds) : 0)

        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
