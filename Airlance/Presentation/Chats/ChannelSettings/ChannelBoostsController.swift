import Haptics
import ListUI
import Observers
import UIKit

final class ChannelBoostsController: ScreenViewController {
    private let id: String
    private let dependencies: ChannelSettingsDependencies
    private let listView = ListView(theme: ListTheme())
    private let hero = ChannelBoostsHero()
    private var observation: ObservationToken?

    init(id: String, dependencies: ChannelSettingsDependencies) {
        self.id = id
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        observation = dependencies.onAir.observe { [weak self] _ in
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        listView.theme = .settings(presentation.theme)
        navigationItem.title = presentation.strings.channelSettingsBoosts
        render()
    }

    private func render() {
        guard isViewLoaded, let channel = dependencies.onAir.channel(id) else {
            return
        }

        let strings = presentation.strings
        let level = OnAirLevel(score: channel.score)
        hero.update(channel: channel, level: level, presentation: presentation)
        var items: [any ListItem] = [
            SpacerItem(id: "top", height: 8),
            ViewHostItem(id: "hero", height: ChannelBoostsHero.height, content: hero, revision: channel.score),
            SectionHeaderItem(id: "stats-header", title: strings.channelBoostsOverview),
        ]
        items += statRows(channel, level: level).positioned() as [any ListItem]
        items.append(SpacerItem(id: "gap", height: 24))
        items += actionRows().positioned() as [any ListItem]
        items.append(FootnoteItem(id: "share-hint", text: strings.channelBoostsShareHint))
        listView.apply(items: items, animated: false)
    }

    private func statRows(_ channel: OnAirChannel, level: OnAirLevel) -> [SettingsOptionItem] {
        let strings = presentation.strings
        let left = level.next.map { next in
            strings.compactCount(next.threshold - channel.score)
        }

        return [
            SettingsOptionItem(id: "level", title: strings.channelBoostsLevel, detail: level.title(strings)),
            SettingsOptionItem(
                id: "score",
                title: strings.channelBoostsScore,
                detail: strings.compactCount(channel.score)
            ),
            SettingsOptionItem(
                id: "votes",
                title: strings.channelBoostsVotes,
                detail: strings.compactCount(channel.boosts)
            ),
            SettingsOptionItem(id: "left", title: strings.channelBoostsLeft, detail: left ?? "—"),
        ]
    }

    private func actionRows() -> [SettingsOptionItem] {
        let strings = presentation.strings

        return [
            SettingsOptionItem(
                id: "levels",
                title: strings.boostLevelsLink,
                symbol: "sparkles",
                accessory: .chevron,
                onSelect: { [weak self] in
                    self?.showLevels()
                }
            ),
            SettingsOptionItem(
                id: "share",
                title: strings.channelBoostsShare,
                symbol: "square.and.arrow.up",
                isAction: true,
                onSelect: { [weak self] in
                    self?.share()
                }
            ),
        ]
    }

    private var boostLink: URL? {
        URL(string: "https://airlance.app/boost/\(dependencies.settings.link(of: id))")
    }

    private func showLevels() {
        let content = ChannelLevelsController(channelID: id, store: dependencies.onAir, presentation: presentation)
        let sheet = FloatingSheetController(content: content, theme: presentation.theme) { _ in
            720
        }
        present(sheet, animated: false)
    }

    private func share() {
        guard let boostLink else {
            return
        }

        Haptics.play(.tap)
        present(UIActivityViewController(activityItems: [boostLink], applicationActivities: nil), animated: true)
    }
}

final class ChannelBoostsHero: UIView {
    static let height: CGFloat = 170

    private let gradient = CAGradientLayer()
    private let score = UILabel()
    private let track = UIView()
    private let fill = UIView()
    private let current = UILabel()
    private let nextLabel = UILabel()
    private let info = UILabel()
    private var progress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        clipsToBounds = true
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        layer.addSublayer(gradient)
        score.font = .systemFont(ofSize: 28, weight: .heavy)
        score.textColor = .white
        track.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        track.layer.cornerRadius = 15
        track.clipsToBounds = true
        fill.backgroundColor = .white
        nextLabel.textAlignment = .right
        for label in [current, nextLabel] {
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .white
        }
        info.font = .systemFont(ofSize: 14)
        info.textColor = .white
        info.numberOfLines = 2
        track.addSubview(fill)
        for subview in [score, track, current, nextLabel, info] as [UIView] {
            addSubview(subview)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(channel: OnAirChannel, level: OnAirLevel, presentation: PresentationData) {
        let strings = presentation.strings
        gradient.colors = [presentation.theme.colors.accent.cgColor, (level.next ?? level).color.cgColor]
        score.text = "★ " + strings.compactCount(channel.score)
        current.text = level.title(strings)
        nextLabel.text = level.next?.title(strings)
        info.text = strings.channelBoostsHint
        progress = CGFloat(OnAirLevel.progress(score: channel.score))
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        let width = bounds.width - 36
        score.frame = CGRect(x: 18, y: 14, width: width, height: 38)
        track.frame = CGRect(x: 18, y: 60, width: width, height: 30)
        fill.frame = CGRect(x: 0, y: 0, width: width * progress, height: 30)
        current.frame = CGRect(x: 30, y: 60, width: width / 2 - 12, height: 30)
        nextLabel.frame = CGRect(x: 18 + width / 2, y: 60, width: width / 2 - 12, height: 30)
        current.textColor = progress > 0.2 ? .darkGray : .white
        info.frame = CGRect(x: 18, y: 100, width: width, height: 56)
    }
}
