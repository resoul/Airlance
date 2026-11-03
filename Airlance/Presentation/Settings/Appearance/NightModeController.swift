import ListUI
import Observers
import Theme
import UIKit

final class NightModeController: ScreenViewController {
    private let dependencies: AppearanceDependencies
    private let listView = ListView(theme: ListTheme())
    private let styles = ThemeCardsView(layout: .grid(columns: 2), aspect: 0.62)
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
        styles.onSelect = { [weak self] index in
            self?.change { night in
                night.style = NightStyle.allCases[index]
            }
        }
        observation = dependencies.themeStore.observeSettings { [weak self] _ in
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
        navigationItem.title = presentation.strings.themeNightSwitch
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded, view.bounds.width > 0 else {
            return
        }

        let strings = presentation.strings
        let theme = presentation.theme
        let night = dependencies.themeStore.settings.night
        var items: [any ListItem] = [SpacerItem(id: "top", height: 8)]
        let schedules = NightSchedule.allCases.map { schedule in
            SettingsOptionItem(
                id: schedule.rawValue,
                title: strings.title(for: schedule),
                accessory: .check(night.schedule == schedule),
                onSelect: { [weak self] in
                    self?.change { night in
                        night.schedule = schedule
                    }
                }
            )
        }
        items += schedules.positioned()
        items.append(FootnoteItem(id: "hint", text: hint(night.schedule)))
        items += detailItems(night)
        let cards = NightStyle.allCases.map { style in
            ThemeCardModel.night(style, theme: theme, caption: strings.title(for: style))
        }
        styles.apply(cards, selected: NightStyle.allCases.firstIndex(of: night.style), theme: theme)
        var hasher = Hasher()
        hasher.combine(night.style)
        hasher.combine(theme.accent)
        items += [
            SectionHeaderItem(id: "style", title: strings.themeNightStyle),
            ViewHostItem(
                id: "styles",
                height: styles.height(for: view.bounds.width - 32, count: 2, captions: true),
                content: styles,
                revision: hasher.finalize()
            ),
            SpacerItem(id: "bottom", height: 24),
        ]
        listView.apply(items: items, animated: false)
    }

    private func hint(_ schedule: NightSchedule) -> String {
        presentation.strings.pack.string("theme.night." + schedule.rawValue + ".hint")
    }

    private func detailItems(_ night: NightSettings) -> [any ListItem] {
        let strings = presentation.strings
        switch night.schedule {
        case .scheduled:
            let locale = strings.pack.locale
            let rows = [
                timeRow("from", title: strings.themeNightFrom, minute: night.from, locale: locale) { night, minute in
                    night.from = minute
                },
                timeRow("to", title: strings.themeNightTo, minute: night.to, locale: locale) { night, minute in
                    night.to = minute
                },
            ]

            return [SpacerItem(id: "time-gap", height: 12)] + rows.positioned()
        case .automatic:
            return [
                SpacerItem(id: "auto-gap", height: 12),
                SettingsSliderItem(
                    id: "brightness",
                    value: Int((night.brightness * 100).rounded()),
                    leftTitle: "0%",
                    rightTitle: "100%",
                    title: { value in
                        strings.themeNightBrightness("\(value)%")
                    },
                    onChange: { [weak self] value in
                        self?.change { night in
                            night.brightness = Double(value) / 100
                        }
                    }
                ),
                FootnoteItem(id: "auto-hint", text: strings.themeNightBrightnessHint),
            ]
        case .system, .off:
            return []
        }
    }

    private func timeRow(
        _ id: String,
        title: String,
        minute: Int,
        locale: Locale,
        apply: @escaping @MainActor @Sendable (inout NightSettings, Int) -> Void
    ) -> SettingsOptionItem {
        SettingsOptionItem(
            id: id,
            title: title,
            detail: TimePickerController.text(minute, locale: locale),
            accessory: .chevron,
            onSelect: { [weak self] in
                self?.pickTime(minute, title: title, apply: apply)
            }
        )
    }

    private func pickTime(
        _ minute: Int,
        title: String,
        apply: @escaping @MainActor @Sendable (inout NightSettings, Int) -> Void
    ) {
        let picker = TimePickerController(minute: minute, title: title)
        picker.onDone = { [weak self] value in
            self?.change { night in
                apply(&night, value)
            }
        }
        let navigation = UINavigationController(rootViewController: picker)
        navigation.sheetPresentationController?.detents = [.medium()]
        present(navigation, animated: true)
    }

    private func change(_ edit: (inout NightSettings) -> Void) {
        let store = dependencies.themeStore
        var night = store.settings.night
        edit(&night)
        guard night != store.settings.night else {
            return
        }

        Task {
            try? await store.setNight(night)
        }
    }
}
