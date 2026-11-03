import ListUI
import Observers
import Theme
import UIKit

final class ChatThemesController: ScreenViewController {
    private let dependencies: AppearanceDependencies
    private let listView = ListView(theme: ListTheme())
    private let grid = ThemeCardsView(layout: .grid(columns: 3), aspect: 1.25)
    private let preview = ChatAppearancePreview()
    private let styles = ThemeCardsView(layout: .grid(columns: 2), aspect: 0.62)
    private let accents = AccentRowView()
    private var observation: ObservationToken?

    init(dependencies: AppearanceDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        let store = dependencies.themeStore
        grid.onSelect = { index in
            Task {
                try? await store.apply(ChatThemePreset.allCases[index])
            }
        }
        styles.onSelect = { index in
            var night = store.settings.night
            night.style = NightStyle.allCases[index]
            Task {
                try? await store.setNight(night)
            }
        }
        accents.onSelect = { accent in
            Task {
                try? await store.setAccent(accent)
            }
        }
        observation = store.observeSettings { [weak self] _ in
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let changed = listView.frame.width != view.bounds.width
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        if changed {
            render()
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.themeChatThemes
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded, view.bounds.width > 0 else {
            return
        }

        let strings = presentation.strings
        let theme = presentation.theme
        let settings = dependencies.themeStore.settings
        let width = view.bounds.width - 32
        let presets = ChatThemePreset.allCases
        update(settings, theme: theme)
        let revision = Self.revision(settings, theme: theme)
        let items: [any ListItem] = [
            SectionHeaderItem(id: "pick", title: strings.themePick),
            ViewHostItem(
                id: "grid",
                height: grid.height(for: width, count: presets.count, captions: false),
                content: grid,
                revision: revision
            ),
            SectionHeaderItem(id: "own", title: strings.themeOwn),
            ViewHostItem(id: "preview", height: 170, content: preview, revision: revision),
            SpacerItem(id: "preview-gap", height: 14),
            ViewHostItem(
                id: "styles",
                height: styles.height(for: width, count: 2, captions: true),
                content: styles,
                revision: revision
            ),
            FootnoteItem(id: "styles-hint", text: strings.themeNightStyleHint),
            ViewHostItem(id: "accents", height: AccentRowView.height, content: accents, revision: revision),
            SpacerItem(id: "accent-gap", height: 8),
            gradientRow(settings),
            SpacerItem(id: "bottom", height: 24),
        ]
        listView.apply(items: items, animated: false)
    }

    private func gradientRow(_ settings: ThemeSettings) -> SettingsOptionItem {
        let store = dependencies.themeStore

        return SettingsOptionItem(
            id: "gradient",
            title: presentation.strings.themeGradient,
            accessory: .toggle(settings.chat.fill == .gradient),
            onToggle: { isOn in
                var chat = store.settings.chat
                chat.fill = isOn ? .gradient : .solid
                Task {
                    try? await store.setChat(chat)
                }
            }
        )
    }

    private func update(_ settings: ThemeSettings, theme: AppTheme) {
        let strings = presentation.strings
        let presets = ChatThemePreset.allCases
        let cards = presets.map { preset in
            ThemeCardModel.preset(preset, theme: theme)
        }
        let selected = presets.firstIndex { preset in
            preset.matches(settings)
        }
        grid.apply(cards, selected: selected, theme: theme)
        preview.apply(.make(presentation))
        let styleCards = NightStyle.allCases.map { style in
            ThemeCardModel.night(style, theme: theme, caption: strings.title(for: style))
        }
        styles.apply(styleCards, selected: NightStyle.allCases.firstIndex(of: settings.night.style), theme: theme)
        accents.apply(selected: settings.accent, theme: theme, title: strings.title(for:))
    }

    private static func revision(_ settings: ThemeSettings, theme: AppTheme) -> Int {
        var hasher = Hasher()
        hasher.combine(settings.accent)
        hasher.combine(settings.chat.wallpaper)
        hasher.combine(settings.chat.fill)
        hasher.combine(settings.night.style)
        hasher.combine(theme.appearance == .dark)

        return hasher.finalize()
    }
}
