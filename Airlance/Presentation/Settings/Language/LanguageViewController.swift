import ListUI
import Localization
import Observers
import UIKit

struct LanguageDependencies {
    let presentationContext: PresentationContext
    let localizationStore: LocalizationStore
    let translation: TranslationSettings
}

final class LanguageViewController: ScreenViewController {
    private let dependencies: LanguageDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private let search = SearchHeaderView()
    private var observations: [ObservationToken] = []

    init(dependencies: LanguageDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        search.onChange = { [weak self] _ in
            self?.render()
        }
        listView.headerView = search
        listView.headerHeight = SearchHeaderView.height
        listView.scrollView.keyboardDismissMode = .onDrag
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observations = dependencies.translation.observe { [weak self] in
            self?.render()
        } + [
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
        navigationItem.title = presentation.strings.settingsLanguage
        search.apply(presentation, placeholder: presentation.strings.languageSearch)
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        var items: [any ListItem] = []
        if search.query.isEmpty {
            items += translationItems()
        }
        items.append(SectionHeaderItem(id: "interface", title: presentation.strings.languageInterface))
        items += languageItems().positioned()
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
    }

    private func translationItems() -> [any ListItem] {
        let strings = presentation.strings
        let translation = dependencies.translation
        let isSupported = MessageTranslator.isSupported
        var rows = [
            SettingsOptionItem(
                id: "button",
                title: strings.languageShowTranslate,
                accessory: .toggle(isSupported && translation.showsButton),
                isEnabled: isSupported,
                onToggle: { isOn in
                    translation.setShowsButton(isOn)
                }
            ),
            SettingsOptionItem(
                id: "chats",
                title: strings.languageTranslateChats,
                accessory: .toggle(isSupported && translation.translatesChats),
                isEnabled: isSupported,
                onToggle: { isOn in
                    translation.setTranslatesChats(isOn)
                }
            ),
        ]
        if isSupported, translation.showsButton || translation.translatesChats {
            rows.append(SettingsOptionItem(
                id: "skip",
                title: strings.languageDoNotTranslate,
                detail: skippedTitle,
                accessory: .chevron,
                onSelect: { [router] in
                    router.open(.settingsPage(.translationSkip))
                }
            ))
        }

        let hint = isSupported ? strings.languageTranslateHint : strings.languageTranslateUnsupported

        return [SectionHeaderItem(id: "translation", title: strings.languageTranslation)] + rows.positioned() + [
            FootnoteItem(id: "translation-hint", text: hint),
            SpacerItem(id: "translation-gap", height: 12),
        ]
    }

    private var skippedTitle: String {
        let skipped = dependencies.translation.skipped
        let locale = presentation.strings.pack.locale
        guard !skipped.isEmpty else {
            return presentation.strings.languageNone
        }

        guard skipped.count == 1, let code = skipped.first else {
            return "\(skipped.count)"
        }

        return (locale.localizedString(forLanguageCode: code) ?? code).capitalized(with: locale)
    }

    private func languageItems() -> [SettingsOptionItem] {
        let store = dependencies.localizationStore
        let selected = store.settings.selection
        let locale = presentation.strings.pack.locale
        let query = search.query
        let options = [LanguageSelection.system] + store.languages.map(LanguageSelection.language)

        return options.compactMap { option in
            let (title, subtitle) = names(of: option, locale: locale)
            guard query.isEmpty || title.localizedCaseInsensitiveContains(query)
                || subtitle.localizedCaseInsensitiveContains(query) else {
                return nil
            }

            return SettingsOptionItem(
                id: id(of: option),
                title: title,
                subtitle: subtitle,
                accessory: .check(option == selected),
                onSelect: { [weak self] in
                    self?.select(option)
                }
            )
        }
    }

    private func names(of option: LanguageSelection, locale: Locale) -> (String, String) {
        switch option {
        case .system:
            let code = Locale.preferredLanguages.first.map { identifier in
                Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
            } ?? "en"

            return (presentation.strings.languageSystem, LanguageCode(code).nativeName)
        case .language(let code):
            let name = locale.localizedString(forLanguageCode: code.rawValue) ?? code.rawValue

            return (name.capitalized(with: locale), code.nativeName)
        }
    }

    private func id(of option: LanguageSelection) -> String {
        switch option {
        case .system:
            "system"
        case .language(let code):
            code.rawValue
        }
    }

    private func select(_ option: LanguageSelection) {
        guard option != dependencies.localizationStore.settings.selection else {
            return
        }

        let store = dependencies.localizationStore
        Task {
            try? await store.select(option)
        }
    }
}
