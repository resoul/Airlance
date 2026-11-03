import AirlanceUI
@preconcurrency import AsyncDisplayKit
import ListUI
import Observers
import UIKit

struct TabSettingsDependencies {
    let presentationContext: PresentationContext
    let settings: TabSettings
    let accounts: any AccountSwitching
}

final class TabSettingsController: ScreenViewController {
    private static let previewHeight: CGFloat = 92

    private let dependencies: TabSettingsDependencies
    private let listView = ListView(theme: ListTheme())
    private let preview = TabBarPreviewView()
    private var shown: [AppRoute] = []
    private var hidden: [AppRoute] = []
    private var observation: ObservationToken?

    init(dependencies: TabSettingsDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        listView.headerView = preview
        listView.headerHeight = Self.previewHeight
        listView.onMove = { [weak self] id, index in
            self?.move(id, to: index)
        }
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observation = dependencies.settings.observe { [weak self] tabs in
            self?.load(tabs)
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
        title = presentation.strings.tabsTitle
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

    private func load(_ tabs: [AppRoute]) {
        guard tabs != shown else {
            return
        }

        shown = tabs
        hidden = TabSettings.all.filter { tab in
            !tabs.contains(tab)
        }
        render(animated: !listView.scrollView.isDragging)
    }

    private func render(animated: Bool) {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let items = AppTabItems.make(TabSettings.all, presentation: presentation, accounts: dependencies.accounts)
        let byTab = Dictionary(uniqueKeysWithValues: zip(TabSettings.all, items))
        let shownRows = shown.map { tab in
            row(tab, item: byTab[tab], isShown: true)
        }
        let hiddenRows = hidden.map { tab in
            row(tab, item: byTab[tab], isShown: false)
        }
        var list: [any ListItem] = [SectionHeaderItem(id: "shown", title: strings.tabsShown)]
        list += Self.positioned(shownRows)
        list.append(FootnoteItem(id: "hint", text: strings.tabsShownHint))
        if !hiddenRows.isEmpty {
            list.append(SectionHeaderItem(id: "hidden", title: strings.tabsHidden))
            list += Self.positioned(hiddenRows)
        }
        listView.apply(items: list, animated: animated)
        preview.update(
            AppTabItems.make(shown, presentation: presentation, accounts: dependencies.accounts),
            selected: shown.firstIndex(of: .chats) ?? 0,
            theme: presentation.theme
        )
    }

    private func row(_ tab: AppRoute, item: TabBarItem?, isShown: Bool) -> TabRowItem {
        let isRequired = TabSettings.required.contains(tab)
        let control: TabRowItem.Control = isRequired ? .locked : (isShown ? .remove : .add)

        return TabRowItem(
            id: "tab-" + tab.segment.name,
            title: item?.title ?? tab.segment.name,
            detail: isRequired ? presentation.strings.tabsRequired : nil,
            image: item?.image,
            control: control,
            isMovable: isShown,
            position: .middle
        ) { [weak self] in
            self?.toggle(tab, isShown: isShown)
        }
    }

    private func toggle(_ tab: AppRoute, isShown: Bool) {
        if isShown {
            shown.removeAll { item in
                item == tab
            }
            hidden.insert(tab, at: 0)
        } else {
            hidden.removeAll { item in
                item == tab
            }
            shown.insert(tab, at: shown.last == .settings ? shown.count - 1 : shown.count)
        }
        save(animated: true)
    }

    private func move(_ id: String, to index: Int) {
        let position = index - 1
        guard
            let source = shown.firstIndex(where: { tab in
                "tab-" + tab.segment.name == id
            }),
            shown.indices.contains(position)
        else {
            return
        }

        shown.insert(shown.remove(at: source), at: position)
        save(animated: false)
    }

    private func save(animated: Bool) {
        render(animated: animated)
        dependencies.settings.setTabs(shown)
    }

    private static func positioned(_ rows: [TabRowItem]) -> [any ListItem] {
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
