@preconcurrency import AsyncDisplayKit
import DeviceContacts
import ListUI
import Observers
import Permissions
import PermissionsAPI
import UIKit

struct ContactsDependencies {
    let presentationContext: PresentationContext
    let contactsSync: ContactsSync
    let permissionStore: PermissionStore
    let permissionFlow: PermissionFlow
}

final class ContactsViewController: ScreenViewController {
    private let dependencies: ContactsDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private let accessView = ContactsAccessView()
    private let emptyLabel = UILabel()
    private let searchHeader = SearchHeaderView()
    private var status: PermissionStatus?
    private var sort = DeviceContactsSort.givenName
    private var query = ""
    private var observations: [ObservationToken] = []

    private lazy var addItem = UIBarButtonItem(
        systemItem: .add,
        primaryAction: UIAction { [weak self] _ in
            self?.router.open(.newContact)
        }
    )

    init(dependencies: ContactsDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        setUpViews()

        observations = [
            dependencies.permissionStore.observe { [weak self] snapshot in
                self?.status = snapshot.status(of: .contacts)
                self?.render()
            },
            dependencies.contactsSync.store.observe { [weak self] _ in
                self?.render()
            },
            dependencies.contactsSync.observeSort { [weak self] sort in
                self?.sort = sort
                self?.updateSortMenu()
            },
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        accessView.frame = view.bounds.inset(by: view.safeAreaInsets)
        emptyLabel.frame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 24, dy: 0)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme

        navigationItem.title = presentation.strings.contactsTitle
        searchHeader.apply(presentation, placeholder: presentation.strings.contactsSearch)
        listView.theme = ListTheme(
            background: theme.colors.background,
            rowBackground: theme.colors.background,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.subheadline
        )
        accessView.apply(presentation)
        emptyLabel.font = theme.fonts.body
        emptyLabel.textColor = theme.colors.textSecondary
        updateSortMenu()
        render()
    }

    private func setUpViews() {
        searchHeader.onChange = { [weak self] query in
            self?.searchChanged(query)
        }
        listView.headerView = searchHeader
        listView.headerHeight = SearchHeaderView.height
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)
        view.addSubview(accessView)
        accessView.onAllow = { [weak self] in
            self?.requestAccess()
        }
    }

    private func requestAccess() {
        Task {
            _ = await dependencies.permissionFlow.authorize(.findFriends, from: self)
        }
    }

    private func searchChanged(_ text: String) {
        guard text != query else {
            return
        }

        query = text
        render(animated: false)
    }

    private func updateSortMenu() {
        let strings = presentation.strings
        let options: [(DeviceContactsSort, String)] = [
            (.givenName, strings.contactsSortGivenName),
            (.familyName, strings.contactsSortFamilyName),
        ]
        let actions = options.map { option in
            UIAction(title: option.1, state: option.0 == sort ? .on : .off) { [weak self] _ in
                self?.selectSort(option.0)
            }
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: strings.contactsSort,
            menu: UIMenu(children: actions)
        )
    }

    private func selectSort(_ sort: DeviceContactsSort) {
        Task {
            try? await dependencies.contactsSync.setSort(sort)
        }
    }

    private func render(animated: Bool = true) {
        guard isViewLoaded else {
            return
        }

        let store = dependencies.contactsSync.store
        let allowed = status?.allowsUse == true
        let contacts = query.isEmpty ? store.contacts : store.contacts.filter { contact in
            contact.matches(query)
        }
        let rows: [any ListItem] = contacts.enumerated().map { index, contact in
            ContactRowItem(
                contact: contact,
                thumbnails: store.thumbnails,
                revision: store.revision,
                showsSeparator: index < contacts.count - 1
            )
        }
        let invite = ActionRowItem(
            id: "invite",
            title: presentation.strings.contactsInvite,
            symbol: "person.badge.plus"
        ) { [router] in
            router.open(.invite)
        }
        let items = query.isEmpty ? [invite] + rows : rows

        accessView.isHidden = status == nil || allowed
        listView.isHidden = !allowed
        navigationItem.rightBarButtonItem = allowed ? addItem : nil
        listView.apply(items: items, animated: animated)

        emptyLabel.text = query.isEmpty ? presentation.strings.contactsEmpty : presentation.strings.contactsNotFound
        emptyLabel.isHidden = !allowed || !store.isLoaded || !contacts.isEmpty
    }
}
