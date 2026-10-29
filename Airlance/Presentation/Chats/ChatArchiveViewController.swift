@preconcurrency import AsyncDisplayKit
import ListUI
import Observers
import UIKit

struct ChatArchiveDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
    let storiesStore: StoriesStore
}

final class ChatArchiveViewController: ScreenViewController {
    private let dependencies: ChatArchiveDependencies
    private let router: AppRouter
    private let listView = ListView(theme: ListTheme())
    private var dateFormatter = ListDateFormatter(locale: .current)
    private var observations: [ObservationToken] = []

    init(dependencies: ChatArchiveDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        listView.allowsSwipeActions = true
        view.addSubnode(listView)
        setContentScrollView(listView.scrollView, for: .bottom)
        observations = [
            dependencies.chatsStore.observe { [weak self] _ in
                self?.render()
            },
            dependencies.storiesStore.observe { [weak self] _ in
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
        let theme = presentation.theme
        navigationItem.title = presentation.strings.chatsArchiveTitle
        dateFormatter = ListDateFormatter(locale: presentation.strings.pack.locale)
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
        render()
    }

    private func render() {
        guard isViewLoaded else {
            return
        }

        let strings = presentation.strings
        let chats = dependencies.chatsStore.chats.filter(\.isArchived).sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }

            return lhs.activityDate > rhs.activityDate
        }
        guard !chats.isEmpty else {
            let empty = ChatsEmptyItem(
                id: "empty",
                title: strings.chatsArchiveEmptyTitle,
                text: strings.chatsArchiveEmptyText,
                symbol: "archivebox"
            )
            listView.apply(items: [empty], animated: true)

            return
        }

        let now = Date()
        let stories = dependencies.storiesStore
        let actions = ChatActions(store: dependencies.chatsStore, presentation: presentation, host: view)
        listView.apply(
            items: chats.map { chat in
                ChatRowItem(
                    chat: chat,
                    timeText: dateFormatter.string(for: chat.activityDate, now: now),
                    story: stories.story(for: chat.id),
                    swipe: actions.swipes(for: chat),
                    draft: ChatRowDraft(
                        title: presentation.strings.chatsDraft,
                        color: presentation.theme.colors.destructive
                    )
                ) { [router] in
                    router.open(.chat(chat.id))
                }
            },
            animated: true
        )
    }
}
