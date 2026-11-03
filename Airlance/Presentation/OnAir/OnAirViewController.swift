import AirlanceUI
@preconcurrency import AsyncDisplayKit
import ListUI
import Observers
import ToastUI
import UIKit

struct OnAirDependencies {
    let presentationContext: PresentationContext
    let store: OnAirStore
    let chatsStore: ChatsStore
}

final class OnAirViewController: ScreenViewController {
    static let seenDelay: TimeInterval = 1

    let dependencies: OnAirDependencies
    let router: AppRouter
    let listView = ListView(theme: ListTheme())
    private let sectionControl = LiquidSegmentedControl()
    private let emptyLabel = UILabel()
    var section = OnAirSection.onAir
    var category: OnAirCategory?
    var newsOptions = OnAirNewsOptions()
    var onlyMine = false
    var keptPosts: Set<String> = []
    var visibleSince: [String: Date] = [:]
    private var joined: Set<String> = []
    var dateFormatter = ListDateFormatter(locale: .current)
    private var observations: [ObservationToken] = []

    init(dependencies: OnAirDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        sectionControl.select(section.rawValue, animated: false)
        sectionControl.onSelect = { [weak self] index in
            self?.sectionChanged(index)
        }
        navigationItem.titleView = sectionControl
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "star.circle"),
            primaryAction: UIAction { [weak self] _ in
                self?.router.open(.myOnAir)
            }
        )
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)
        observations = [
            dependencies.store.observe { [weak self] _ in
                self?.render(animated: true)
            },
            dependencies.chatsStore.observe { [weak self] _ in
                self?.joinedChanged()
            },
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keptPosts = []
        render(animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for id in visibleSince.keys {
            setPostVisible(id, isVisible: false)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        emptyLabel.frame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 24, dy: 0)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let strings = presentation.strings
        title = strings.tabOnAir
        navigationItem.leftBarButtonItem?.accessibilityLabel = strings.onAirMy
        dateFormatter = ListDateFormatter(locale: strings.pack.locale)
        sectionControl.apply(theme)
        sectionControl.setTitles(OnAirSection.allCases.map(strings.onAirTitle))
        listView.theme = ListTheme(
            background: theme.colors.background,
            rowBackground: theme.colors.background,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.subheadline
        )
        emptyLabel.font = theme.fonts.body
        emptyLabel.textColor = theme.colors.textSecondary
        updateFilterItem()
        render(animated: false)
    }

    private func sectionChanged(_ index: Int) {
        guard let next = OnAirSection(rawValue: index), next != section else {
            return
        }

        section = next
        sectionControl.select(index, animated: true)
        keptPosts = []
        updateFilterItem()
        render(animated: false)
        listView.scrollToTop(animated: false)
    }

    func filtersChanged(animated: Bool) {
        keptPosts = []
        updateFilterItem()
        render(animated: animated)
    }

    func render(animated: Bool) {
        guard isViewLoaded else {
            return
        }

        let items = section == .news ? newsItems() : channelItems()
        listView.apply(items: items, animated: animated)
        let strings = presentation.strings
        emptyLabel.text = section == .news && !newsOptions.showsSeen ? strings.onAirAllSeen : strings.onAirEmpty
        emptyLabel.isHidden = !items.isEmpty
    }

    func isJoined(_ channelID: String) -> Bool {
        joined.contains(channelID)
    }

    private func joinedChanged() {
        let chats = dependencies.chatsStore
        let current = Set(dependencies.store.base.map(\.id).filter(chats.isJoined))
        guard current != joined else {
            return
        }

        joined = current
        render(animated: false)
    }

    func open(_ channelID: String) {
        dependencies.store.markSeen(channel: channelID)
        router.navigate(to: [.onAir, .chat(channelID)])
    }

    func setPostVisible(_ id: String, isVisible: Bool) {
        guard !isVisible else {
            visibleSince[id] = visibleSince[id] ?? Date()

            return
        }

        guard let since = visibleSince.removeValue(forKey: id) else {
            return
        }

        if Date().timeIntervalSince(since) >= Self.seenDelay {
            dependencies.store.markSeen(posts: [id], notify: false)
        }
    }

    func boostPost(_ id: String) {
        BoostViewController.present(
            .post(id),
            store: dependencies.store,
            presentationSource: dependencies.presentationContext,
            from: self
        )
    }

    func hideChannel(_ channel: OnAirChannel) {
        let store = dependencies.store
        store.setHidden(true, channel: channel.id)
        Toast(
            presentation.strings.onAirHiddenToast(channel.name),
            symbol: "eye.slash",
            edge: .bottom,
            action: {
                store.setHidden(false, channel: channel.id)
            }
        ).show(theme: presentation.theme, in: view)
    }
}
