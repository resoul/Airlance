@preconcurrency import AsyncDisplayKit
import ListUI
import Observers
import UIKit

final class MyOnAirController: ScreenViewController {
    private let dependencies: OnAirDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private var observation: ObservationToken?

    init(dependencies: OnAirDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observation = dependencies.store.observe { [weak self] _ in
            self?.render(animated: true)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        title = presentation.strings.onAirMy
        view.backgroundColor = theme.colors.background
        listView.theme = ListTheme(
            background: theme.colors.background,
            rowBackground: theme.colors.surface,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.subheadline
        )
        render(animated: false)
    }

    private func render(animated: Bool) {
        guard isViewLoaded else {
            return
        }

        listView.apply(items: budgetItems() + boostItems() + hiddenItems(), animated: animated)
    }

    private func budgetItems() -> [any ListItem] {
        let strings = presentation.strings
        let store = dependencies.store
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = strings.pack.locale
        let reset = formatter.localizedString(for: store.resetDate, relativeTo: Date())

        return [
            SectionHeaderItem(id: "budget-header", title: strings.onAirMyBudget),
            SettingsRowItem(
                id: "budget",
                title: strings.boostBudget(String(store.remaining), String(OnAirStore.weeklyBudget)),
                symbol: "star.circle.fill",
                color: .systemOrange,
                position: .single
            ),
            FootnoteItem(id: "budget-footer", text: strings.boostReset(reset)),
        ]
    }

    private func boostItems() -> [any ListItem] {
        let strings = presentation.strings
        let store = dependencies.store
        var rows: [SettingsRowItem] = store.channels.compactMap { channel in
            let votes = store.myVotes(.channel(channel.id))
            guard votes > 0 else {
                return nil
            }

            return SettingsRowItem(
                id: "boost-" + channel.id,
                title: channel.name,
                symbol: "star.fill",
                color: OnAirLevel(score: channel.score).color,
                detail: strings.onAirMyVotes(String(votes)),
                position: .middle
            ) { [weak self] in
                self?.router.open(.chat(channel.id))
            }
        }
        rows += store.posts.compactMap { post in
            let votes = store.myVotes(.post(post.id))
            guard votes > 0 else {
                return nil
            }

            return SettingsRowItem(
                id: "boost-" + post.id,
                title: post.text,
                symbol: "text.bubble.fill",
                color: .systemBlue,
                detail: strings.onAirMyVotes(String(votes)),
                position: .middle
            ) { [weak self] in
                self?.router.open(.chat(post.channelID))
            }
        }
        let header = SectionHeaderItem(id: "boosts-header", title: strings.onAirMyBoosts)
        guard !rows.isEmpty else {
            return [header, FootnoteItem(id: "boosts-empty", text: strings.onAirMyBoostsEmpty)]
        }

        return [header] + Self.positioned(rows)
    }

    private func hiddenItems() -> [any ListItem] {
        let strings = presentation.strings
        let store = dependencies.store
        let rows = store.channels
            .filter { channel in
                store.hidden.contains(channel.id)
            }
            .map { channel in
                SettingsRowItem(
                    id: "hidden-" + channel.id,
                    title: channel.name,
                    symbol: "eye.slash.fill",
                    color: .systemGray,
                    detail: strings.onAirMyRestore,
                    position: .middle
                ) {
                    store.setHidden(false, channel: channel.id)
                }
            }
        let header = SectionHeaderItem(id: "hidden-header", title: strings.onAirMyHidden)
        guard !rows.isEmpty else {
            return [header, FootnoteItem(id: "hidden-empty", text: strings.onAirMyHiddenEmpty)]
        }

        return [header] + Self.positioned(rows)
    }

    private static func positioned(_ rows: [SettingsRowItem]) -> [any ListItem] {
        rows.enumerated().map { index, row in
            var row = row
            row.position = switch (index, rows.count) {
            case (_, 1):
                .single
            case (0, _):
                .first
            case (rows.count - 1, _):
                .last
            default:
                .middle
            }

            return row
        }
    }
}
