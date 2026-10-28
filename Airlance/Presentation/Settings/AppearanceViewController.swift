import Localization
import Observers
import Theme
import UIKit

struct AppearanceDependencies {
    let presentationContext: PresentationContext
    let themeStore: ThemeStore
    let localizationStore: LocalizationStore
}

final class AppearanceViewController: ScreenViewController {
    private let dependencies: AppearanceDependencies
    private let languageSelections: [LanguageSelection]

    private let appearanceLabel = UILabel()
    private let accentLabel = UILabel()
    private let fontLabel = UILabel()
    private let languageLabel = UILabel()
    private let modeControl: UISegmentedControl
    private let accentControl: UISegmentedControl
    private let fontControl: UISegmentedControl
    private let languageControl: UISegmentedControl
    private var settingsObservations: [ObservationToken] = []

    private var sectionLabels: [UILabel] {
        [appearanceLabel, accentLabel, fontLabel, languageLabel]
    }

    private var controls: [UISegmentedControl] {
        [modeControl, accentControl, fontControl, languageControl]
    }

    init(dependencies: AppearanceDependencies) {
        self.dependencies = dependencies
        languageSelections = [.system] + dependencies.localizationStore.languages.map(LanguageSelection.language)
        modeControl = Self.makeControl(segments: ThemeMode.allCases.count)
        accentControl = Self.makeControl(segments: ThemeAccent.allCases.count)
        fontControl = Self.makeControl(segments: ThemeFont.allCases.count)
        languageControl = Self.makeControl(segments: languageSelections.count)
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        setUpViews()
        settingsObservations = [
            dependencies.themeStore.observeSettings { [weak self] _ in
                self?.showSettings()
            },
            dependencies.localizationStore.observeSettings { [weak self] _ in
                self?.showSettings()
            },
        ]
    }

    private static func makeControl(segments: Int) -> UISegmentedControl {
        UISegmentedControl(items: Array(repeating: "", count: segments))
    }

    private func setUpViews() {
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        accentControl.addTarget(self, action: #selector(accentChanged), for: .valueChanged)
        fontControl.addTarget(self, action: #selector(fontChanged), for: .valueChanged)
        languageControl.addTarget(self, action: #selector(languageChanged), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [
            makeSection(label: appearanceLabel, control: modeControl),
            makeSection(label: accentLabel, control: accentControl),
            makeSection(label: fontLabel, control: fontControl),
            makeSection(label: languageLabel, control: languageControl),
        ])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    private func makeSection(label: UILabel, control: UISegmentedControl) -> UIStackView {
        let section = UIStackView(arrangedSubviews: [label, control])
        section.axis = .vertical
        section.spacing = 8
        section.alignment = .center

        return section
    }

    private func showSettings() {
        let theme = dependencies.themeStore.settings
        let language = dependencies.localizationStore.settings

        modeControl.selectedSegmentIndex = ThemeMode.allCases.firstIndex(of: theme.mode) ?? 0
        accentControl.selectedSegmentIndex = ThemeAccent.allCases.firstIndex(of: theme.accent) ?? 0
        fontControl.selectedSegmentIndex = ThemeFont.allCases.firstIndex(of: theme.font) ?? 0
        languageControl.selectedSegmentIndex = languageSelections.firstIndex(of: language.selection) ?? 0
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        apply(presentation.theme)
        apply(presentation.strings)
    }

    private func apply(_ theme: AppTheme) {
        let colors = theme.colors
        let fonts = theme.fonts

        for label in sectionLabels {
            label.font = fonts.subheadline
            label.textColor = colors.textSecondary
        }

        for control in controls {
            control.selectedSegmentTintColor = colors.accent
            control.setTitleTextAttributes([.font: fonts.subheadline], for: .normal)
        }
    }

    private func apply(_ strings: AppStrings) {
        navigationItem.title = strings.settingsAppearance
        appearanceLabel.text = strings.settingsAppearance
        accentLabel.text = strings.settingsAccent
        fontLabel.text = strings.settingsFont
        languageLabel.text = strings.settingsLanguage

        setTitles(ThemeMode.allCases.map(strings.title(for:)), of: modeControl)
        setTitles(ThemeAccent.allCases.map(strings.title(for:)), of: accentControl)
        setTitles(ThemeFont.allCases.map(strings.title(for:)), of: fontControl)
        setTitles(languageSelections.map(strings.title(for:)), of: languageControl)
    }

    private func setTitles(_ titles: [String], of control: UISegmentedControl) {
        for (index, title) in titles.enumerated() {
            control.setTitle(title, forSegmentAt: index)
        }
    }

    private func perform(_ change: @escaping @MainActor () async throws -> Void) {
        Task {
            do {
                try await change()
            } catch {
                showSettings()
            }
        }
    }

    @objc
    private func modeChanged() {
        let mode = ThemeMode.allCases[modeControl.selectedSegmentIndex]

        perform { [dependencies] in
            try await dependencies.themeStore.setMode(mode)
        }
    }

    @objc
    private func accentChanged() {
        let accent = ThemeAccent.allCases[accentControl.selectedSegmentIndex]

        perform { [dependencies] in
            try await dependencies.themeStore.setAccent(accent)
        }
    }

    @objc
    private func fontChanged() {
        let font = ThemeFont.allCases[fontControl.selectedSegmentIndex]

        perform { [dependencies] in
            try await dependencies.themeStore.setFont(font)
        }
    }

    @objc
    private func languageChanged() {
        let selection = languageSelections[languageControl.selectedSegmentIndex]

        perform { [dependencies] in
            try await dependencies.localizationStore.select(selection)
        }
    }
}
