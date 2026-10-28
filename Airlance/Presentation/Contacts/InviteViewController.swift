@preconcurrency import AsyncDisplayKit
import DeviceContacts
import ListUI
import MessageUI
import Observers
import UIKit

struct InviteDependencies {
    let presentationContext: PresentationContext
    let contactsSync: ContactsSync
}

final class InviteViewController: ScreenViewController {
    private static let buttonHeight: CGFloat = 52

    private let dependencies: InviteDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private let searchHeader = SearchHeaderView()
    private let sendButton = UIButton(type: .system)
    private let messageHandler = MessageComposeHandler()
    private var selected: Set<String> = []
    private var query = ""
    private var contactsObservation: ObservationToken?

    private var contacts: [DeviceContact] {
        dependencies.contactsSync.store.contacts.filter { contact in
            !contact.phoneNumbers.isEmpty
        }
    }

    init(dependencies: InviteDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        searchHeader.onChange = { [weak self] query in
            self?.searchChanged(query)
        }
        listView.headerView = searchHeader
        listView.headerHeight = SearchHeaderView.height
        view.addSubnode(listView)
        sendButton.layer.cornerRadius = Self.buttonHeight / 2
        sendButton.layer.cornerCurve = .continuous
        sendButton.addAction(
            UIAction { [weak self] _ in
                self?.send()
            },
            for: .touchUpInside
        )
        view.addSubview(sendButton)
        messageHandler.onFinish = { [weak self] sent in
            self?.dismiss(animated: true)
            if sent {
                self?.router.dismiss()
            }
        }

        contactsObservation = dependencies.contactsSync.store.observe { [weak self] _ in
            self?.render()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let buttonSpace = sendButton.isHidden ? 0 : Self.buttonHeight + 16
        listView.frame = view.bounds
        listView.contentInsets = UIEdgeInsets(
            top: view.safeAreaInsets.top,
            left: 0,
            bottom: view.safeAreaInsets.bottom + buttonSpace,
            right: 0
        )
        sendButton.frame = CGRect(
            x: safe.minX + 16,
            y: safe.maxY - Self.buttonHeight - 8,
            width: safe.width - 32,
            height: Self.buttonHeight
        )
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme

        navigationItem.title = presentation.strings.inviteTitle
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
        sendButton.backgroundColor = theme.colors.accent
        sendButton.setTitleColor(theme.colors.onAccent, for: .normal)
        sendButton.titleLabel?.font = theme.fonts.headline
        render()
    }

    private func searchChanged(_ text: String) {
        guard text != query else {
            return
        }

        query = text
        render(animated: false)
    }

    private func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
        render(animated: false)
    }

    private func toggleAll() {
        let all = Set(contacts.map(\.id))
        selected = selected == all ? [] : all
        render(animated: false)
    }

    private func render(animated: Bool = true) {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let store = dependencies.contactsSync.store
        let all = contacts
        selected.formIntersection(all.map(\.id))
        let visible = query.isEmpty ? all : all.filter { contact in
            contact.matches(query)
        }
        let items = visible.enumerated().map { index, contact in
            ContactRowItem(
                contact: contact,
                thumbnails: store.thumbnails,
                revision: store.revision,
                showsSeparator: index < visible.count - 1,
                isSelected: selected.contains(contact.id),
                onSelect: { [weak self] in
                    self?.toggle(contact.id)
                }
            )
        }
        listView.apply(items: items, animated: animated)

        let allSelected = !all.isEmpty && selected.count == all.count
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: allSelected ? strings.inviteDeselectAll : strings.inviteSelectAll,
            primaryAction: UIAction { [weak self] _ in
                self?.toggleAll()
            }
        )
        navigationItem.rightBarButtonItem?.isEnabled = !all.isEmpty

        let wasHidden = sendButton.isHidden
        sendButton.isHidden = selected.isEmpty
        sendButton.setTitle(strings.inviteSend(selected.count), for: .normal)
        if wasHidden != sendButton.isHidden {
            view.setNeedsLayout()
        }
    }

    private func send() {
        let phones = contacts
            .filter { contact in
                selected.contains(contact.id)
            }
            .compactMap(\.phoneNumbers.first)
        let message = presentation.strings.inviteMessage
        guard !phones.isEmpty else {
            return
        }

        guard MFMessageComposeViewController.canSendText() else {
            let share = UIActivityViewController(activityItems: [message], applicationActivities: nil)
            present(share, animated: true)

            return
        }

        let composer = MFMessageComposeViewController()
        composer.recipients = phones
        composer.body = message
        composer.messageComposeDelegate = messageHandler
        present(composer, animated: true)
    }
}

@MainActor
private final class MessageComposeHandler: NSObject, MFMessageComposeViewControllerDelegate {
    var onFinish: (@MainActor (Bool) -> Void)?

    nonisolated func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        let sent = result == .sent
        MainActor.assumeIsolated {
            onFinish?(sent)
        }
    }
}
