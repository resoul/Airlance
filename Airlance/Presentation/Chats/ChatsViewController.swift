import AirlanceUI
@preconcurrency import AsyncDisplayKit
import ChatFolders
import ListUI
import Observers
import Stories
import UIKit

struct ChatsDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
    let storiesStore: StoriesStore
    let chatFolders: ChatFolderStore
}

enum ChatsPage: Equatable {
    case all
    case folder(ChatFolder)

    var id: String {
        switch self {
        case .all:
            "all"
        case .folder(let folder):
            folder.id
        }
    }
}

final class ChatsViewController: ScreenViewController {
    let dependencies: ChatsDependencies
    let router: AppRouter
    let pager = ListPager(theme: ListTheme())
    let tabs = LiquidTabsView()
    let header = StoriesHeaderView()
    let expansion = StoriesExpansion(rowHeight: StoriesHeaderView.rowHeight)
    var pages: [ChatsPage] = [.all]
    var dateFormatter = ListDateFormatter(locale: .current)

    private let composeButton = UIButton(type: .system)
    private var observations: [ObservationToken] = []

    var hasFolders: Bool {
        pages.count > 1
    }

    init(dependencies: ChatsDependencies, router: AppRouter) {
        self.dependencies = dependencies
        self.router = router
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        composeButton.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        composeButton.addAction(
            UIAction { [router] _ in
                router.open(.newChat)
            },
            for: .touchUpInside
        )
        header.trailingView = composeButton

        pager.setPageCount(pages.count)
        view.addSubnode(pager)
        view.addSubview(header)
        view.addSubview(tabs)
        tabs.isHidden = true
        bindPager()
        bindLists()
        bindStories()
        trackCurrentList()

        observations = [
            dependencies.chatsStore.observe { [weak self] _ in
                self?.render()
            },
            dependencies.chatFolders.observe { [weak self] _ in
                self?.render()
            },
            dependencies.storiesStore.observe { [weak self] _ in
                self?.renderStories()
                self?.render()
            },
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        header.safeTop = safe.top
        header.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: safe.top + StoriesHeaderView.barHeight + StoriesHeaderView.rowHeight
        )
        pager.frame = view.bounds
        expansion.baseInset = safe.top + StoriesHeaderView.barHeight + (hasFolders ? LiquidTabsView.height : 0)
        updateInsets(top: expansion.topInset)
        updateExpansion()
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let strings = presentation.strings

        navigationItem.title = strings.chatsTitle
        header.title = strings.chatsTitle
        header.theme = StoriesHeaderTheme(
            background: theme.colors.background,
            title: theme.colors.textPrimary,
            titleFont: theme.fonts.headline,
            name: theme.colors.textPrimary,
            nameFont: theme.fonts.caption,
            unseen: theme.colors.accent,
            seen: theme.colors.textSecondary.withAlphaComponent(0.45)
        )
        composeButton.tintColor = theme.colors.accent
        dateFormatter = ListDateFormatter(locale: strings.pack.locale)
        tabs.apply(theme)
        pager.theme = ListTheme(
            background: theme.colors.background,
            rowBackground: theme.colors.background,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.subheadline
        )
        renderStories()
        render()
    }

    func bindLists() {
        for list in pager.lists {
            list.allowsSwipeActions = !hasFolders
            list.onScroll = { [weak self] list in
                self?.listDidScroll(list)
            }
            list.onWillEndDragging = { [weak self] list, target in
                self?.targetOffset(for: list, proposed: target) ?? target
            }
        }
    }

    func trackCurrentList() {
        setContentScrollView(pager.currentList?.scrollView, for: .bottom)
        contentScrollViewDidChange()
    }

    private func bindPager() {
        pager.onPosition = { [weak self] position in
            self?.tabs.setPosition(position)
        }
        pager.onSelect = { [weak self] index in
            self?.tabs.select(index, animated: true)
            self?.trackCurrentList()
            self?.keepStoriesOnPageChange()
            self?.updateExpansion()
        }
        tabs.onSelect = { [weak self] index in
            self?.pager.select(index, animated: true)
        }
    }

    private func bindStories() {
        expansion.onInsetChange = { [weak self] top in
            self?.updateInsets(top: top)
        }
        header.onStackTap = { [weak self] in
            self?.expandStories()
        }
        header.onOpen = { [router] peerID in
            router.open(.stories(peerID))
        }
    }
}

extension ChatsViewController: StoryTransitionSource {
    func storyAvatarFrame(for peerID: String) -> CGRect? {
        guard isViewLoaded, let window = view.window else {
            return nil
        }

        return header.avatarFrame(for: peerID, in: window)
    }
}
