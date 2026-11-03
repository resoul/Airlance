import Device
import ListUI
import Observers
import Theme
import UIKit

struct AppearanceDependencies {
    let presentationContext: PresentationContext
    let themeStore: ThemeStore
    let videoNotes: VideoNoteSettings
}

final class AppearanceViewController: ScreenViewController {
    private let dependencies: AppearanceDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private let preview = ChatAppearancePreview()
    private let presets = ThemeCardsView(layout: .strip(width: 92), aspect: 1.32)
    private var observation: ObservationToken?
    private var videoNoteObservations: [ObservationToken] = []

    init(dependencies: AppearanceDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        presets.onSelect = { [weak self] index in
            self?.applyPreset(ChatThemePreset.allCases[index])
        }
        observation = dependencies.themeStore.observeSettings { [weak self] _ in
            self?.render()
        }
        videoNoteObservations = dependencies.videoNotes.observe { [weak self] in
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
        navigationItem.title = presentation.strings.settingsAppearance
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let theme = presentation.theme
        let settings = dependencies.themeStore.settings
        preview.apply(.make(presentation))
        let selected = ChatThemePreset.allCases.firstIndex { preset in
            preset.matches(settings)
        }
        let cards = ChatThemePreset.allCases.map { preset in
            ThemeCardModel.preset(preset, theme: theme)
        }
        presets.apply(cards, selected: selected, theme: theme)
        var items: [any ListItem] = [
            SectionHeaderItem(id: "theme", title: colorThemeTitle),
            ViewHostItem(id: "preview", height: 170, content: preview, revision: revision),
            SpacerItem(id: "preview-gap", height: 12),
            ViewHostItem(id: "presets", height: 122, content: presets, revision: revision),
            SpacerItem(id: "presets-gap", height: 12),
        ]
        items += themeRows(settings).positioned()
        items.append(SpacerItem(id: "night-gap", height: 28))
        items += nightRows(settings).positioned()
        items.append(SpacerItem(id: "chat-gap", height: 28))
        items += chatRows(settings).positioned()
        items.append(SectionHeaderItem(id: "videoNotes", title: presentation.strings.videoNotesTitle))
        items += videoNoteRows().positioned()
        items.append(SectionHeaderItem(id: "font", title: presentation.strings.settingsFont))
        items += fontRows(settings).positioned()
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
    }

    private var revision: Int {
        var hasher = Hasher()
        hasher.combine(dependencies.themeStore.settings.accent)
        hasher.combine(dependencies.themeStore.settings.chat.wallpaper)
        hasher.combine(presentation.theme.appearance == .dark)

        return hasher.finalize()
    }

    private var colorThemeTitle: String {
        let strings = presentation.strings
        let theme = presentation.theme
        let mode = theme.appearance == .dark ? strings.title(for: theme.nightStyle) : strings.themeDay

        return strings.themeColorTitle(mode)
    }

    private func themeRows(_ settings: ThemeSettings) -> [SettingsOptionItem] {
        let strings = presentation.strings
        let router = router

        return [
            SettingsOptionItem(id: "themes", title: strings.themeChatThemes, accessory: .chevron, onSelect: {
                router.open(.settingsPage(.chatThemes))
            }),
            SettingsOptionItem(
                id: "wallpapers",
                title: strings.themeWallpapers,
                detail: strings.title(for: settings.chat.wallpaper),
                accessory: .chevron,
                onSelect: {
                    router.open(.settingsPage(.wallpapers))
                }
            ),
        ]
    }

    private func nightRows(_ settings: ThemeSettings) -> [SettingsOptionItem] {
        let strings = presentation.strings
        let store = dependencies.themeStore
        let router = router
        let isManual = settings.night.schedule == .off

        return [
            SettingsOptionItem(
                id: "night",
                title: strings.themeNightMode,
                accessory: .toggle(presentation.theme.appearance == .dark),
                isEnabled: isManual,
                onToggle: { isOn in
                    Task {
                        try? await store.setMode(isOn ? .dark : .light)
                    }
                }
            ),
            SettingsOptionItem(
                id: "schedule",
                title: strings.themeNightSwitch,
                detail: strings.title(for: settings.night.schedule),
                accessory: .chevron,
                onSelect: {
                    router.open(.settingsPage(.nightMode))
                }
            ),
        ]
    }

    private func chatRows(_ settings: ThemeSettings) -> [SettingsOptionItem] {
        let strings = presentation.strings
        let router = router

        return [
            SettingsOptionItem(
                id: "text",
                title: strings.chatAppearanceTextSize,
                detail: "\(settings.chat.textSize)",
                accessory: .chevron,
                onSelect: {
                    router.open(.settingsPage(.textSize))
                }
            ),
            SettingsOptionItem(
                id: "corners",
                title: strings.themeCorners,
                detail: "\(settings.chat.bubbleRadius)",
                accessory: .chevron,
                onSelect: {
                    router.open(.settingsPage(.bubbleCorners))
                }
            ),
        ]
    }

    private func videoNoteRows() -> [SettingsOptionItem] {
        let strings = presentation.strings
        let settings = dependencies.videoNotes
        var rows = [
            SettingsOptionItem(
                id: "video-reactions",
                title: strings.videoNotesReactions,
                subtitle: strings.videoNotesReactionsHint,
                accessory: .toggle(settings.reactionsEnabled),
                onToggle: { isOn in
                    settings.setReactionsEnabled(isOn)
                }
            ),
            SettingsOptionItem(
                id: "video-subtitles",
                title: strings.videoNotesAutoSubtitles,
                subtitle: strings.videoNotesAutoSubtitlesHint,
                accessory: .toggle(settings.autoSubtitlesEnabled),
                onToggle: { isOn in
                    settings.setAutoSubtitlesEnabled(isOn)
                }
            ),
        ]
        if DeviceFeatures.volumeCaptureButtons {
            rows.append(SettingsOptionItem(
                id: "video-volume",
                title: strings.videoNotesVolumeZoom,
                subtitle: strings.videoNotesVolumeZoomHint,
                accessory: .toggle(settings.volumeZoomEnabled),
                onToggle: { isOn in
                    settings.setVolumeZoomEnabled(isOn)
                }
            ))
        }

        return rows
    }

    private func fontRows(_ settings: ThemeSettings) -> [SettingsOptionItem] {
        let store = dependencies.themeStore

        return ThemeFont.allCases.map { font in
            SettingsOptionItem(
                id: "font-" + font.rawValue,
                title: presentation.strings.title(for: font),
                accessory: .check(settings.font == font),
                onSelect: {
                    Task {
                        try? await store.setFont(font)
                    }
                }
            )
        }
    }

    private func applyPreset(_ preset: ChatThemePreset) {
        let store = dependencies.themeStore
        Task {
            try? await store.apply(preset)
        }
    }
}
