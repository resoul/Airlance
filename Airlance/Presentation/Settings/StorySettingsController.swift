import DatabaseAPI
import Haptics
import ListUI
import Observers
import Stories
import UIKit

extension StorageKey where Value == Int {
    static let storyLifetimeHours = StorageKey("stories.lifetimeHours", default: StoryLifetime.hours24.rawValue)
}

extension StoryLifetime {
    static let choices: [StoryLifetime] = [.hours12, .hours24, .hours48]
}

struct StorySettingsDependencies {
    let presentationContext: PresentationContext
    let storage: any KeyValueStore
}

final class StorySettingsController: ScreenViewController {
    private let dependencies: StorySettingsDependencies
    private let listView = ListView(theme: ListTheme())
    private var observation: ObservationToken?

    init(dependencies: StorySettingsDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observation = dependencies.storage.observe(.storyLifetimeHours) { [weak self] _ in
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
        navigationItem.title = presentation.strings.settingsStories
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let current = dependencies.storage.value(for: .storyLifetimeHours)
        let storage = dependencies.storage
        let rows = StoryLifetime.choices.map { choice in
            SettingsOptionItem(
                id: "\(choice.rawValue)",
                title: strings.storiesLifetimeHours("\(choice.rawValue)"),
                accessory: .check(choice.rawValue == current),
                onSelect: {
                    Haptics.play(.selection)
                    Task {
                        try? await storage.update(.storyLifetimeHours) { value in
                            value = choice.rawValue
                        }
                    }
                }
            )
        }
        var items: [any ListItem] = [SectionHeaderItem(id: "lifetime", title: strings.storiesLifetimeTitle)]
        items += rows.positioned() as [any ListItem]
        items.append(FootnoteItem(id: "hint", text: strings.storiesLifetimeHint))
        listView.apply(items: items, animated: false)
    }
}
