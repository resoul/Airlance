import Haptics
import Observers
import UIKit

final class ChannelLevelsController: UIViewController {
    private static let inset: CGFloat = 20
    private static let rowHeight: CGFloat = 44

    private let channelID: String
    private let store: OnAirStore
    private let presentation: PresentationData
    private let scroll = UIScrollView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let scoreBubble = UILabel()
    private let track = UIView()
    private let fill = UIView()
    private let currentLabel = UILabel()
    private let nextLabel = UILabel()
    private let infoLabel = UILabel()
    private let voteButton = UIButton(type: .system)
    private var sections: [(pill: UILabel, lines: [UIView], rows: [(UIImageView, UILabel)])] = []
    private var observation: ObservationToken?

    init(channelID: String, store: OnAirStore, presentation: PresentationData) {
        self.channelID = channelID
        self.store = store
        self.presentation = presentation
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupProgress()
        setupSections()
        setupVote()
        observation = store.observe { [weak self] _ in
            self?.update()
        }
        update()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        closeButton.frame = CGRect(x: 16, y: 14, width: 44, height: 44)
        titleLabel.frame = CGRect(x: 68, y: 14, width: width - 136, height: 44)
        voteButton.frame = CGRect(x: 16, y: view.bounds.height - 70, width: width - 32, height: 50)
        scroll.frame = CGRect(x: 0, y: 66, width: width, height: view.bounds.height - 66)
        scroll.contentInset.bottom = 82
        let content = width - Self.inset * 2
        track.frame = CGRect(x: Self.inset, y: 52, width: content, height: 32)
        currentLabel.frame = track.bounds.insetBy(dx: 14, dy: 0)
        nextLabel.frame = track.bounds.insetBy(dx: 14, dy: 0)
        let height = infoLabel.sizeThatFits(CGSize(width: content, height: .greatestFiniteMagnitude)).height
        infoLabel.frame = CGRect(x: Self.inset, y: track.frame.maxY + 16, width: content, height: ceil(height))
        layoutProgress()
        let bottom = layoutSections(top: infoLabel.frame.maxY + 18, width: content)
        scroll.contentSize = CGSize(width: width, height: bottom + 12)
    }

    private func layoutProgress() {
        let progress = CGFloat(currentProgress)
        fill.frame = CGRect(x: 0, y: 0, width: track.bounds.width * progress, height: track.bounds.height)
        let size = scoreBubble.sizeThatFits(CGSize(width: 200, height: 36))
        let width = ceil(size.width) + 24
        let center = track.frame.minX + track.bounds.width * progress
        let x = min(max(Self.inset, center - width / 2), view.bounds.width - Self.inset - width)
        scoreBubble.frame = CGRect(x: x, y: 8, width: width, height: 36)
    }

    private func layoutSections(top: CGFloat, width: CGFloat) -> CGFloat {
        var y = top
        for section in sections {
            let pillWidth = min(ceil(section.pill.intrinsicContentSize.width) + 28, width - 60)
            let pillX = Self.inset + (width - pillWidth) / 2
            section.pill.frame = CGRect(x: pillX, y: y, width: pillWidth, height: 30)
            section.lines[0].frame = CGRect(x: Self.inset, y: y + 15, width: pillX - Self.inset - 10, height: 0.5)
            let rightX = pillX + pillWidth + 10
            section.lines[1].frame = CGRect(x: rightX, y: y + 15, width: Self.inset + width - rightX, height: 0.5)
            y += 38
            for (icon, label) in section.rows {
                icon.frame = CGRect(x: Self.inset, y: y, width: 32, height: Self.rowHeight)
                label.frame = CGRect(x: Self.inset + 44, y: y, width: width - 44, height: Self.rowHeight)
                y += Self.rowHeight
            }
            y += 12
        }

        return y
    }

    private var channel: OnAirChannel? {
        store.channel(channelID)
    }

    private var currentProgress: Double {
        OnAirLevel.progress(score: channel?.score ?? 0)
    }

    private func setupHeader() {
        let theme = presentation.theme
        view.addSubview(scroll)
        titleLabel.text = presentation.strings.boostLevelsTitle
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = theme.colors.textPrimary
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        closeButton.tintColor = theme.colors.textPrimary
        closeButton.backgroundColor = theme.colors.textSecondary.withAlphaComponent(0.14)
        closeButton.layer.cornerRadius = 22
        closeButton.accessibilityLabel = presentation.strings.chatCancel
        closeButton.addAction(
            UIAction { [weak self] _ in
                self?.floatingSheet?.close()
            },
            for: .touchUpInside
        )
        view.addSubview(closeButton)
    }

    private func setupProgress() {
        let theme = presentation.theme
        scoreBubble.backgroundColor = theme.colors.accent
        scoreBubble.textColor = theme.colors.onAccent
        scoreBubble.font = HistoryStyle.bold(theme.fonts.body)
        scoreBubble.textAlignment = .center
        scoreBubble.layer.cornerRadius = 18
        scoreBubble.layer.cornerCurve = .continuous
        scoreBubble.clipsToBounds = true
        track.backgroundColor = theme.colors.textSecondary.withAlphaComponent(0.16)
        track.layer.cornerRadius = 16
        track.layer.cornerCurve = .continuous
        track.clipsToBounds = true
        fill.backgroundColor = theme.colors.accent
        nextLabel.textAlignment = .right
        for label in [currentLabel, nextLabel] {
            label.font = HistoryStyle.bold(theme.fonts.caption)
            label.textColor = theme.colors.textPrimary
        }
        infoLabel.font = theme.fonts.subheadline
        infoLabel.textColor = theme.colors.textPrimary
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0
        for subview in [fill, currentLabel, nextLabel] {
            track.addSubview(subview)
        }
        for subview in [track, scoreBubble, infoLabel] {
            scroll.addSubview(subview)
        }
    }

    private func setupSections() {
        let theme = presentation.theme
        let strings = presentation.strings
        let levels = OnAirLevel.allCases.filter { level in
            level != .none
        }
        sections = levels.map { level in
            let pill = UILabel()
            pill.text = level.title(strings)
            pill.font = HistoryStyle.bold(theme.fonts.subheadline)
            pill.textColor = .black
            pill.textAlignment = .center
            pill.backgroundColor = level.color
            pill.layer.cornerRadius = 15
            pill.layer.cornerCurve = .continuous
            pill.clipsToBounds = true
            let lines = [UIView(), UIView()]
            for line in lines {
                line.backgroundColor = theme.colors.separator
            }
            let rows = level.perks(strings).map { perk -> (UIImageView, UILabel) in
                let icon = UIImageView(image: UIImage(systemName: perk.symbol))
                icon.contentMode = .center
                icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 21)
                icon.tintColor = theme.colors.accent
                let label = UILabel()
                label.text = perk.text
                label.font = theme.fonts.body
                label.textColor = theme.colors.textPrimary
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.8

                return (icon, label)
            }
            for subview in lines + [pill] + rows.flatMap({ row in
                [row.0 as UIView, row.1]
            }) {
                scroll.addSubview(subview)
            }

            return (pill, lines, rows)
        }
    }

    private func setupVote() {
        let colors = presentation.theme.colors
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = colors.accent
        configuration.baseForegroundColor = colors.onAccent
        configuration.background.cornerRadius = 25
        voteButton.configuration = configuration
        voteButton.addAction(
            UIAction { [weak self] _ in
                self?.vote()
            },
            for: .touchUpInside
        )
        view.addSubview(voteButton)
    }

    private func vote() {
        guard store.boost(.channel(channelID), votes: 1) else {
            Haptics.play(.warning)

            return
        }

        Haptics.play(.success)
    }

    private func update() {
        guard let channel else {
            return
        }

        let strings = presentation.strings
        let level = OnAirLevel(score: channel.score)
        scoreBubble.text = "★ " + strings.compactCount(channel.score)
        currentLabel.text = level.title(strings)
        nextLabel.text = level.next?.title(strings)
        if let next = level.next {
            let left = strings.compactCount(next.threshold - channel.score)
            infoLabel.text = strings.boostLevelsLeft(channel.name, left, next.title(strings))
        } else {
            infoLabel.text = strings.boostLevelsMax(channel.name)
        }
        let canVote = store.canBoost(1, to: .channel(channelID))
        voteButton.isEnabled = canVote
        voteButton.configuration?.title = canVote ? strings.boostLevelsVote : strings.boostEmpty
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.view.layoutIfNeeded()
        }
    }
}
