import ListUI
import Protocol
import ToastUI
import UIKit

struct NewChatSearch {
    let search: @MainActor (String) async throws -> [SearchPerson]
    let open: @MainActor (SearchPerson) async throws -> String
    let chats: @MainActor (String) async throws -> [ServerChat]
}

struct NewChatDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
    let search: NewChatSearch?
}

final class NewChatViewController: ScreenViewController {
    private static let minQuery = 3
    private static let debounce: Duration = .milliseconds(300)

    private let dependencies: NewChatDependencies
    private let router: AppRouter
    private let contactButtons: [UIButton]
    private let listView = ListView(theme: ListTheme())
    private let searchHeader = SearchHeaderView()
    private let hintLabel = UILabel()
    private var people: [SearchPerson] = []
    private var publicChats: [ServerChat] = []
    private var pending: Task<Void, Never>?

    init(dependencies: NewChatDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        contactButtons = dependencies.search == nil ? DemoChats.ids.map { id in
            UIButton.action {
                router.open(.profile(id))
            }
        } : []
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard dependencies.search != nil else {
            placeActionButtons(contactButtons)

            return
        }

        view.addSubnode(listView)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        view.addSubview(hintLabel)
        searchHeader.onChange = { [weak self] query in
            self?.queryChanged(query)
        }
        listView.headerView = searchHeader
        listView.headerHeight = SearchHeaderView.height
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        listView.frame = view.bounds
        listView.contentInsets = view.safeAreaInsets
        hintLabel.frame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 24, dy: 0)
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let strings = presentation.strings
        navigationItem.title = strings.newChatTitle
        for (id, button) in zip(DemoChats.ids, contactButtons) {
            button.apply(title: dependencies.chatsStore.chat(id)?.name ?? id, theme: presentation.theme)
        }
        searchHeader.apply(presentation, placeholder: strings.newChatSearch)
        hintLabel.font = presentation.theme.fonts.body
        hintLabel.textColor = presentation.theme.colors.textSecondary
        listView.theme = ListTheme(
            background: presentation.theme.colors.background,
            rowBackground: presentation.theme.colors.background,
            primary: presentation.theme.colors.textPrimary,
            secondary: presentation.theme.colors.textSecondary,
            separator: presentation.theme.colors.separator,
            accent: presentation.theme.colors.accent,
            titleFont: presentation.theme.fonts.body,
            subtitleFont: presentation.theme.fonts.subheadline
        )
        render()
    }

    private func queryChanged(_ query: String) {
        pending?.cancel()
        guard query.count >= Self.minQuery, let search = dependencies.search else {
            people = []
            publicChats = []
            render()

            return
        }

        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else {
                return
            }

            async let foundPeople = try? search.search(query)
            async let foundChats = try? search.chats(query)
            let (found, chats) = await (foundPeople ?? [], foundChats ?? [])
            guard !Task.isCancelled, let self else {
                return
            }

            self.people = found
            self.publicChats = chats
            self.render()
        }
    }

    private func render() {
        let query = searchHeader.query
        let strings = presentation.strings
        hintLabel.text = query.count < Self.minQuery ? strings.newChatHint : strings.contactsNotFound
        hintLabel.isHidden = !people.isEmpty || !publicChats.isEmpty
        let chatRows = publicChats.map { chat in
            ActionRowItem(id: chat.chatID, title: Self.title(of: chat), symbol: Self.symbol(of: chat)) { [weak self] in
                self?.open(chat)
            }
        }
        let personRows = people.map { person in
            ActionRowItem(id: person.subject, title: Self.title(of: person), symbol: "person.circle") { [weak self] in
                self?.open(person)
            }
        }
        listView.apply(items: personRows + chatRows, animated: false)
    }

    private func open(_ chat: ServerChat) {
        if !chat.details.isMember {
            dependencies.chatsStore.addServerPreview(.preview(of: chat))
        }
        router.show(.chat(chat.chatID))
    }

    private static func title(of chat: ServerChat) -> String {
        "\(chat.details.title) · @\(chat.details.link)"
    }

    private static func symbol(of chat: ServerChat) -> String {
        chat.details.kind == .channel ? "megaphone" : "person.3"
    }

    private func open(_ person: SearchPerson) {
        guard let search = dependencies.search else {
            return
        }

        Task { [weak self] in
            do {
                let id = try await search.open(person)
                self?.dependencies.chatsStore.addServerPreview(.server(id: id, name: Self.name(of: person)))
                self?.router.show(.chat(id))
            } catch {
                self?.showFailure()
            }
        }
    }

    private func showFailure() {
        guard let window = view.window else {
            return
        }

        Toast(presentation.strings.newChatFailed).show(theme: presentation.theme, in: window)
    }

    private static func name(of person: SearchPerson) -> String {
        let parts = [person.firstName, person.lastName].filter { part in
            !part.isEmpty
        }

        return parts.joined(separator: " ")
    }

    private static func title(of person: SearchPerson) -> String {
        person.username.isEmpty ? name(of: person) : "\(name(of: person)) · @\(person.username)"
    }
}
