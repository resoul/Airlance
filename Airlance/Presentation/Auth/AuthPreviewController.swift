import ListUI
import UIKit

final class AuthPreviewController: ScreenViewController {
    private let presentationContext: PresentationContext
    private let listView = ListView(theme: ListTheme())

    init(presentationContext: PresentationContext) {
        self.presentationContext = presentationContext
        super.init(presentationSource: presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.authPreviewTitle
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        let rows = AuthPreviewScenario.allCases.map(row)
        var items: [any ListItem] = [SpacerItem(id: "top", height: 8)]
        items += rows.positioned() as [any ListItem]
        items.append(FootnoteItem(id: "hint", text: presentation.strings.authPreviewHint))
        listView.apply(items: items, animated: false)
    }

    private func row(_ scenario: AuthPreviewScenario) -> SettingsOptionItem {
        let strings = presentation.strings
        let title: String
        let subtitle: String
        let symbol: String
        switch scenario {
        case .newUser:
            title = strings.authPreviewNew
            subtitle = strings.authPreviewNewDetail
            symbol = "person.badge.plus"
        case .returning:
            title = strings.authPreviewReturning
            subtitle = strings.authPreviewReturningDetail
            symbol = "person.badge.key.fill"
        case .sessionEnded:
            title = strings.authPreviewEnded
            subtitle = strings.authPreviewEndedDetail
            symbol = "clock.badge.exclamationmark"
        }

        return SettingsOptionItem(
            id: scenario.rawValue,
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            iconColor: .systemBlue,
            accessory: .chevron,
            onSelect: { [weak self] in
                self?.open(scenario)
            }
        )
    }

    private func open(_ scenario: AuthPreviewScenario) {
        AuthPreviewFlow(scenario: scenario, presentationContext: presentationContext).start(from: self)
    }
}
