import ListUI
import Observers
import UIKit

struct TranslationSkipDependencies {
    let presentationContext: PresentationContext
    let translation: TranslationSettings
}

final class TranslationSkipController: ScreenViewController {
    static let languages = [
        "en", "uk", "es", "de", "fr", "it", "pl", "pt", "nl", "sv", "cs", "tr", "ar", "he", "hi", "id", "ja", "ko",
        "zh", "th", "vi", "ru",
    ]

    private let dependencies: TranslationSkipDependencies
    private let listView = ListView(theme: ListTheme())
    private let search = SearchHeaderView()
    private var observations: [ObservationToken] = []

    init(dependencies: TranslationSkipDependencies) {
        self.dependencies = dependencies
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
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.languageDoNotTranslate
        search.apply(presentation, placeholder: presentation.strings.languageSearch)
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let translation = dependencies.translation
        let skipped = translation.skipped
        let locale = presentation.strings.pack.locale
        let query = search.query
        let rows = Self.languages.compactMap { code -> SettingsOptionItem? in
            let title = (locale.localizedString(forLanguageCode: code) ?? code).capitalized(with: locale)
            let native = Locale(identifier: code).localizedString(forLanguageCode: code)?
                .capitalized(with: Locale(identifier: code)) ?? code
            guard query.isEmpty || title.localizedCaseInsensitiveContains(query)
                || native.localizedCaseInsensitiveContains(query) else {
                return nil
            }

            return SettingsOptionItem(
                id: code,
                title: title,
                subtitle: native,
                accessory: .check(skipped.contains(code)),
                onSelect: {
                    var next = translation.skipped
                    if next.contains(code) {
                        next.remove(code)
                    } else {
                        next.insert(code)
                    }
                    translation.setSkipped(next)
                }
            )
        }
        let items: [any ListItem] = [SpacerItem(id: "top", height: 8)] + rows.positioned() + [
            FootnoteItem(id: "hint", text: presentation.strings.languageDoNotTranslateHint),
        ]
        listView.apply(items: items, animated: false)
    }
}
