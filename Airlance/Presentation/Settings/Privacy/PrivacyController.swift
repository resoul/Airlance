import AirlanceUI
import ListUI
import Observers
import Protocol
import ToastUI
import UIKit

enum PrivacyRow: String, CaseIterable, Sendable {
    case phone
    case photos
    case bio
    case messages
    case search

    var levels: [PrivacyLevel] {
        switch self {
        case .phone, .photos, .bio:
            [.everyone, .contacts, .nobody]
        case .messages:
            [.everyone, .contacts]
        case .search:
            [.everyone, .nobody]
        }
    }

    var page: SettingsPage {
        switch self {
        case .phone:
            .privacyPhone
        case .photos:
            .privacyPhotos
        case .bio:
            .privacyBio
        case .messages:
            .privacyMessages
        case .search:
            .privacySearch
        }
    }

    func level(in settings: PrivacySettings) -> PrivacyLevel {
        switch self {
        case .phone:
            settings.phone
        case .photos:
            settings.photos
        case .bio:
            settings.bio
        case .messages:
            settings.messages
        case .search:
            settings.search
        }
    }

    func applying(_ level: PrivacyLevel, to settings: PrivacySettings) -> PrivacySettings {
        var next = settings
        switch self {
        case .phone:
            next.phone = level
        case .photos:
            next.photos = level
        case .bio:
            next.bio = level
        case .messages:
            next.messages = level
        case .search:
            next.search = level
        }

        return next
    }

    func title(_ strings: AppStrings) -> String {
        switch self {
        case .phone:
            strings.privacyPhone
        case .photos:
            strings.privacyPhotos
        case .bio:
            strings.privacyBio
        case .messages:
            strings.privacyMessages
        case .search:
            strings.privacySearch
        }
    }

    func hint(_ strings: AppStrings) -> String {
        switch self {
        case .phone:
            strings.privacyPhoneHint
        case .photos:
            strings.privacyPhotosHint
        case .bio:
            strings.privacyBioHint
        case .messages:
            strings.privacyMessagesHint
        case .search:
            strings.privacySearchHint
        }
    }
}

extension PrivacyLevel {
    func title(_ strings: AppStrings) -> String {
        switch self {
        case .everyone:
            strings.privacyEveryone
        case .contacts:
            strings.privacyContacts
        case .nobody:
            strings.privacyNobody
        }
    }
}

struct PrivacyDependencies {
    let presentationContext: PresentationContext
    let privacy: PrivacyStore
}

final class PrivacyController: ScreenViewController {
    private let dependencies: PrivacyDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private var observation: ObservationToken?

    init(dependencies: PrivacyDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observation = dependencies.privacy.observe { [weak self] _ in
            self?.render()
        }
        dependencies.privacy.refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.settingsPrivacy
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let privacy = dependencies.privacy
        let router = router
        let blocked = SettingsOptionItem(
            id: "blocked",
            title: strings.privacyBlocked,
            detail: privacy.blocked.isEmpty ? nil : "\(privacy.blocked.count)",
            symbol: "hand.raised.fill",
            iconColor: .systemRed,
            accessory: .chevron,
            onSelect: {
                router.open(.settingsPage(.blocked))
            }
        )
        let rows = PrivacyRow.allCases.map { row in
            SettingsOptionItem(
                id: row.rawValue,
                title: row.title(strings),
                detail: row.level(in: privacy.settings).title(strings),
                accessory: .chevron,
                onSelect: {
                    router.open(.settingsPage(row.page))
                }
            )
        }
        var items: [any ListItem] = [blocked, SpacerItem(id: "gap", height: 20)]
        items.append(SectionHeaderItem(id: "section", title: strings.settingsPrivacy))
        items += rows.positioned() as [any ListItem]
        items.append(SpacerItem(id: "bottom", height: 24))
        listView.apply(items: items, animated: false)
    }
}

final class PrivacyOptionController: ScreenViewController {
    private let row: PrivacyRow
    private let dependencies: PrivacyDependencies
    private let listView = ListView(theme: ListTheme())
    private var observation: ObservationToken?

    init(row: PrivacyRow, dependencies: PrivacyDependencies) {
        self.row = row
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observation = dependencies.privacy.observe { [weak self] _ in
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
        navigationItem.title = row.title(presentation.strings)
        listView.theme = .settings(presentation.theme)
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let current = row.level(in: dependencies.privacy.settings)
        let rows = row.levels.map { level in
            SettingsOptionItem(
                id: "\(level.rawValue)",
                title: level.title(strings),
                accessory: .check(level == current),
                onSelect: { [weak self] in
                    self?.choose(level)
                }
            )
        }
        var items = rows.positioned() as [any ListItem]
        items.append(FootnoteItem(id: "hint", text: row.hint(strings)))
        listView.apply(items: items, animated: false)
    }

    private func choose(_ level: PrivacyLevel) {
        let privacy = dependencies.privacy
        let next = row.applying(level, to: privacy.settings)
        Task { [weak self] in
            do {
                try await privacy.update(next)
            } catch {
                self?.showFailure()
            }
        }
    }

    private func showFailure() {
        guard let window = view.window else {
            return
        }

        Toast(presentation.strings.privacyFailed).show(theme: presentation.theme, in: window)
    }
}

final class BlockedListController: ScreenViewController {
    private let dependencies: PrivacyDependencies
    private let listView = ListView(theme: ListTheme())
    private let emptyLabel = UILabel()
    private var observation: ObservationToken?

    init(dependencies: PrivacyDependencies) {
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)
        observation = dependencies.privacy.observe { [weak self] _ in
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        emptyLabel.frame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 24, dy: 0)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = presentation.strings.privacyBlocked
        listView.theme = .settings(presentation.theme)
        emptyLabel.text = presentation.strings.privacyBlockedEmpty
        emptyLabel.font = presentation.theme.fonts.body
        emptyLabel.textColor = presentation.theme.colors.textSecondary
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let people = dependencies.privacy.blocked
        emptyLabel.isHidden = !people.isEmpty
        let rows = people.map { person in
            SettingsOptionItem(
                id: person.subject,
                title: Self.name(of: person),
                subtitle: person.username.isEmpty ? nil : "@\(person.username)",
                onSelect: { [weak self] in
                    self?.confirmUnblock(person)
                }
            )
        }
        listView.apply(items: rows.positioned() as [any ListItem], animated: false)
    }

    private func confirmUnblock(_ person: SearchPerson) {
        let strings = presentation.strings
        let privacy = dependencies.privacy
        PopupAlert.show(
            title: Self.name(of: person),
            message: nil,
            actions: [
                PopupAlertAction(title: strings.profileUnblock, style: .destructive) {
                    Task {
                        try? await privacy.setBlocked(person.subject, isBlocked: false)
                    }
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }

    private static func name(of person: SearchPerson) -> String {
        let parts = [person.firstName, person.lastName].filter { part in
            !part.isEmpty
        }

        return parts.isEmpty ? person.username : parts.joined(separator: " ")
    }
}
