@preconcurrency import AsyncDisplayKit
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
}

final class SettingsViewController: ScreenViewController {
    private let dependencies: SettingsDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private let header = SettingsHeaderView()
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
        listView.headerHeight = SettingsHeaderView.height
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)

        observations = [
            dependencies.themeStore.observeSettings { [weak self] _ in
                self?.render()
            },
            dependencies.localizationStore.observeSettings { [weak self] _ in
                self?.render()
            },
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme

        navigationItem.title = presentation.strings.settingsTitle
        header.apply(presentation)
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: isDark ? "sun.max.fill" : "moon.fill"),
            primaryAction: UIAction { [weak self] _ in
                self?.toggleTheme(isDark: isDark)
            }
        )
        render()
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

        return bar.convert(CGPoint(x: bar.bounds.maxX - 36, y: bar.bounds.midY), to: window)
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let sections = Dictionary(grouping: SettingsEntry.allCases, by: \.section)
        var items: [any ListItem] = []
        for section in sections.keys.sorted() {
            let entries = sections[section] ?? []
            items.append(SpacerItem(id: "spacer-\(section)", height: section == 0 ? 8 : 28))
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
            return strings.title(for: dependencies.themeStore.settings.mode)
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
