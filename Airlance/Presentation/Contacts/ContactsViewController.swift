@preconcurrency import AsyncDisplayKit
import DeviceContacts
import ListUI
import Observers
import Permissions
import PermissionsAPI
import Protocol
import ToastUI
import UIKit

struct ContactsDependencies {
    let presentationContext: PresentationContext
    let contactsSync: ContactsSync
    let permissionStore: PermissionStore
    let permissionFlow: PermissionFlow
    var serverContacts: ServerContactsStore?
    var openChat: (@MainActor (ServerContact) async throws -> Void)?
}

final class ContactsViewController: ScreenViewController {
    fileprivate let dependencies: ContactsDependencies
    fileprivate let router: AppRouter
    fileprivate let listView = ListView(theme: ListTheme())
    fileprivate let accessView = ContactsAccessView()
    fileprivate let emptyLabel = UILabel()
    private let searchHeader = SearchHeaderView()
    fileprivate var status: PermissionStatus?
    private var sort = DeviceContactsSort.givenName
    fileprivate var query = ""
    private var observations: [ObservationToken] = []

    fileprivate lazy var addItem = UIBarButtonItem(
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
        if let contacts = dependencies.serverContacts {
            observations.append(contacts.observe { [weak self] _ in
                self?.render()
            })
        }
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

    fileprivate func requestAccess() {
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

        if let contacts = dependencies.serverContacts, contacts.isServerBacked {
            renderServer(contacts, animated: animated)

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

extension ContactsViewController {
    fileprivate func renderServer(_ contacts: ServerContactsStore, animated: Bool) {
        let allowed = status?.allowsUse == true
        if allowed {
            contacts.syncDevice(dependencies.contactsSync.store.contacts)
        }
        let items = serverItems(contacts, allowed: allowed)
        accessView.isHidden = true
        listView.isHidden = false
        navigationItem.rightBarButtonItem = addItem
        listView.apply(items: items, animated: animated)
        emptyLabel.text = presentation.strings.contactsNotFound
        emptyLabel.isHidden = query.isEmpty || !items.isEmpty
    }

    private func serverItems(_ contacts: ServerContactsStore, allowed: Bool) -> [any ListItem] {
        let strings = presentation.strings
        let inApp = contacts.contacts.filter { contact in
            query.isEmpty || contact.displayName.localizedCaseInsensitiveContains(query)
                || contact.person.username.localizedCaseInsensitiveContains(query)
        }
        let invitable = allowed ? invitableContacts(contacts) : []
        var items: [any ListItem] = query.isEmpty ? [actionRow(allowed: allowed)] : []
        if !inApp.isEmpty {
            items.append(SectionHeaderItem(id: "in-app", title: strings.contactsInApp))
            items += inApp.enumerated().map { index, contact in
                serverRow(contact, showsSeparator: index < inApp.count - 1)
            }
        }
        if !invitable.isEmpty {
            items.append(SectionHeaderItem(id: "to-invite", title: strings.contactsToInvite))
            items += invitable.enumerated().map { index, contact in
                inviteRow(contact, showsSeparator: index < invitable.count - 1)
            }
        }

        return items
    }

    private func invitableContacts(_ contacts: ServerContactsStore) -> [DeviceContact] {
        let region = PhoneDigits.currentRegion

        return dependencies.contactsSync.store.contacts.filter { contact in
            let isMatched = contact.phoneNumbers.contains { number in
                contacts.matchedPhones.contains(PhoneDigits.international(number, region: region))
            }

            return !isMatched && (query.isEmpty || contact.matches(query))
        }
    }

    private func actionRow(allowed: Bool) -> any ListItem {
        let strings = presentation.strings
        guard allowed else {
            let symbol = "arrow.triangle.2.circlepath"

            return ActionRowItem(id: "sync", title: strings.contactsSync, symbol: symbol) { [weak self] in
                self?.requestAccess()
            }
        }

        return ActionRowItem(id: "invite", title: strings.contactsInvite, symbol: "person.badge.plus") { [router] in
            router.open(.invite)
        }
    }

    private func serverRow(_ contact: ServerContact, showsSeparator: Bool) -> any ListItem {
        let name = contact.displayName
        let username = contact.person.username
        let line = username.isEmpty ? contact.phone : "@\(username)"
        let row = DeviceContact(
            id: contact.person.subject,
            givenName: contact.customFirstName,
            familyName: contact.customLastName,
            displayName: name,
            phoneNumbers: line.isEmpty ? [] : [line],
            hasImage: false
        )

        return ContactRowItem(
            contact: row,
            thumbnails: dependencies.contactsSync.store.thumbnails,
            revision: contact.person.photoMediaID.hashValue,
            showsSeparator: showsSeparator,
            remoteAvatar: PeerAvatars.descriptor(id: contact.person.subject, name: name),
            onSelect: { [weak self] in
                self?.open(contact)
            }
        )
    }

    private func inviteRow(_ contact: DeviceContact, showsSeparator: Bool) -> any ListItem {
        let store = dependencies.contactsSync.store

        return ContactRowItem(
            contact: contact,
            thumbnails: store.thumbnails,
            revision: store.revision,
            showsSeparator: showsSeparator,
            onSelect: { [router] in
                router.open(.invite)
            }
        )
    }

    private func open(_ contact: ServerContact) {
        guard let openChat = dependencies.openChat else {
            return
        }

        Task { [weak self] in
            do {
                try await openChat(contact)
            } catch {
                self?.showOpenFailure()
            }
        }
    }

    private func showOpenFailure() {
        guard let window = view.window else {
            return
        }

        Toast(presentation.strings.newChatFailed).show(theme: presentation.theme, in: window)
    }
}
