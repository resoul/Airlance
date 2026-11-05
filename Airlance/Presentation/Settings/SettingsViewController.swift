@preconcurrency import AsyncDisplayKit
import AvatarUI
import LiquidUI
import ListUI
import Localization
import Observers
import Theme
import UIKit

struct SettingsDependencies {
    let presentationContext: PresentationContext
    let themeStore: ThemeStore
    let localizationStore: LocalizationStore
    let accounts: any AccountSwitching
    let myProfile: MyProfileStore
}

final class SettingsViewController: ScreenViewController {
    private let dependencies: SettingsDependencies

    var accounts: any AccountSwitching {
        dependencies.accounts
    }

    var myProfile: MyProfileStore {
        dependencies.myProfile
    }

    let router: AppRouter
    let listView = ListView(theme: ListTheme())
    let header = SettingsHeaderView()
    var geometry = SettingsHeaderGeometry()
    var photos: [AvatarDescriptor] = []
    var photoIndex = 0
    var isExpanded = false
    var isNavigationBarFilled = false
    var openSpring = Spring(0, stiffness: 15, dampingRatio: 0.78)
    lazy var openDriver = DisplayLinkDriver { [weak self] deltaTime in
        self?.stepOpen(deltaTime)
    }
    private var offsetObservation: NSKeyValueObservation?
    private var observations: [ObservationToken] = []

    init(dependencies: SettingsDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        listView.headerView = header
        listView.headerHeight = SettingsHeaderGeometry.foldedHeight
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        header.onPhotoTap = { [weak self] position in
            self?.photoTapped(at: position)
        }
        header.onPhotoSwipe = { [weak self] forward in
            self?.photoSwiped(forward: forward)
        }
        let scrollView = listView.scrollView
        offsetObservation = scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] _, change in
            guard change.oldValue != change.newValue else {
                return
            }

            MainActor.assumeIsolated {
                self?.scrollChanged()
            }
        }
        applyNavigationBar(filled: false)

        observations = [
            dependencies.themeStore.observeSettings { [weak self] _ in
                self?.render()
            },
            dependencies.localizationStore.observeSettings { [weak self] _ in
                self?.render()
            },
            dependencies.accounts.observeAccounts { [weak self] in
                self?.render()
            },
            dependencies.myProfile.observe { [weak self] _ in
                self?.updateHeader()
                self?.render()
            },
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        geometry.width = view.bounds.width
        geometry.topInset = view.safeAreaInsets.top
        geometry.safeTop = view.window?.safeAreaInsets.top ?? max(0, view.safeAreaInsets.top - 44)
        layoutHeader()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        geometry.openness > 0.5 ? .lightContent : .default
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        finishOpening()
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme

        navigationItem.backButtonTitle = presentation.strings.settingsTitle
        header.apply(presentation)
        updateHeader()
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
        let isDark = theme.appearance == .dark
        let themeItem = UIBarButtonItem(
            image: UIImage(systemName: isDark ? "sun.max.fill" : "moon.fill"),
            primaryAction: UIAction { [weak self] _ in
                self?.toggleTheme(isDark: isDark)
            }
        )
        let editItem = UIBarButtonItem(
            title: presentation.strings.profileEditAction,
            primaryAction: UIAction { [weak self] _ in
                self?.collapseForEditing()
                self?.router.open(.settingsPage(.editProfile))
            }
        )
        navigationItem.rightBarButtonItems = [editItem, themeItem]
        applyBarTint()
        render()
    }

    private func updateHeader() {
        let profile = dependencies.myProfile.profile
        header.update(profile)
        reloadPhotos()
        view.setNeedsLayout()
    }

    private func toggleTheme(isDark: Bool) {
        let store = dependencies.themeStore
        let reveal = view.window.map { window in
            LiquidThemeReveal.cover(window, from: themeTogglePoint(in: window))
        }

        Task {
            try? await store.setMode(isDark ? .light : .dark)
            reveal?.reveal()
        }
    }

    private func themeTogglePoint(in window: UIWindow) -> CGPoint {
        guard let bar = navigationController?.navigationBar else {
            return CGPoint(x: window.bounds.maxX - 36, y: window.safeAreaInsets.top + 22)
        }

        return bar.convert(CGPoint(x: bar.bounds.maxX - 96, y: bar.bounds.midY), to: window)
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let sections = Dictionary(grouping: SettingsEntry.allCases, by: \.section)
        var items: [any ListItem] = [SpacerItem(id: "spacer-accounts", height: 8)]
        let accounts = accountRows()
        items += accounts.enumerated().map { index, row in
            var row = row
            row.position = position(index, count: accounts.count)

            return row
        }
        for section in sections.keys.sorted() {
            let entries = sections[section] ?? []
            items.append(SpacerItem(id: "spacer-\(section)", height: 28))
            items += entries.enumerated().map { index, entry in
                row(entry, position: position(index, count: entries.count))
            }
        }
        items.append(SpacerItem(id: "spacer-bottom", height: 24))
        listView.apply(items: items, animated: false)
    }

    private func row(_ entry: SettingsEntry, position: CardPosition) -> SettingsRowItem {
        let router = router
        var action: (@MainActor () -> Void)?
        if let route = entry.route {
            action = {
                router.open(route)
            }
        }

        return SettingsRowItem(
            id: entry.rawValue,
            title: entry.title(presentation.strings),
            symbol: entry.symbol,
            color: entry.color,
            detail: detail(for: entry),
            position: position,
            onSelect: action
        )
    }

    private func detail(for entry: SettingsEntry) -> String? {
        let strings = presentation.strings

        switch entry {
        case .devices:
            return "3"
        case .passcode:
            return strings.settingsOff
        case .appearance:
            return strings.title(for: dependencies.themeStore.settings.night.schedule)
        case .language:
            return strings.title(for: dependencies.localizationStore.settings.selection)
        default:
            return nil
        }
    }

    private func position(_ index: Int, count: Int) -> CardPosition {
        switch (index == 0, index == count - 1) {
        case (true, true):
            .single
        case (true, false):
            .first
        case (false, true):
            .last
        case (false, false):
            .middle
        }
    }
}
