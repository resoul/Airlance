import AirlanceUI
@preconcurrency import AsyncDisplayKit
import AvatarUI
import LiquidUI
import ListUI
import UIKit

struct ProfileDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
}

final class ProfileViewController: ScreenViewController {
    let id: String
    let peer: ProfilePeer
    let photos: [AvatarDescriptor]
    let router: AppRouter
    let header = ProfileHeaderView()
    let pager = PanePager()
    let navigationBar = ProfileNavigationBar()
    let monthPill = UILabel()
    let mediaPane = ProfileMediaPane()
    let listPanes = ProfileAttachmentItem.Kind.allCases.map { _ in
        ListPane(list: ListView(theme: ListTheme()))
    }

    var geometry = ProfileHeaderGeometry()
    var openSpring = Spring(0, stiffness: 15, dampingRatio: 0.78)
    var isExpanded = false
    var isMuted = false
    var photoIndex = 0
    var monthGeneration = 0
    let monthFormatter = DateFormatter()

    lazy var container = CollapsingContainer(header: header, pager: pager)
    lazy var openDriver = DisplayLinkDriver { [weak self] deltaTime in
        self?.stepOpen(deltaTime)
    }

    private let tabs = LiquidTabsView()
    private var savedPopGesture: Bool?

    init(id: String, dependencies: ProfileDependencies, router: AppRouter) {
        self.id = id
        self.router = router
        peer = ProfilePeer(id: id, chat: dependencies.chatsStore.chat(id))
        photos = peer.avatars
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(container.view)
        pager.setTabsView(tabs, height: LiquidTabsView.height)
        pager.setPanes([mediaPane] + listPanes)
        bindPaging()
        bindHeader()
        monthPill.alpha = 0
        monthPill.textAlignment = .center
        monthPill.textColor = .white
        monthPill.backgroundColor = UIColor(white: 0, alpha: 0.5)
        monthPill.clipsToBounds = true
        view.addSubview(monthPill)
        view.addSubview(navigationBar)
        showPhoto()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if let gesture = navigationController?.interactivePopGestureRecognizer {
            savedPopGesture = gesture.isEnabled
            gesture.isEnabled = false
        }
        container.setSuspended(false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if let savedPopGesture {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = savedPopGesture
        }
        container.setSuspended(true)
        openDriver.stop()
        monthPill.alpha = 0
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        geometry.width = view.bounds.width
        geometry.navHeight = safe.top + 44
        geometry.safeTop = safe.top
        geometry.infoHeight = header.info.contentHeight
        container.pinnedTopInset = geometry.navHeight
        container.frame = view.bounds
        navigationBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: geometry.navHeight)
        mediaPane.bottomInset = safe.bottom
        for pane in listPanes {
            pane.list.contentInsets.bottom = safe.bottom
        }
        updateHeaderHeight()
        layoutHeader()
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let strings = presentation.strings
        let theme = presentation.theme

        view.backgroundColor = theme.colors.background
        let status = peer.isOnline ? strings.profileOnline : strings.profileLastSeen
        header.apply(name: peer.name, status: status, isOnline: peer.isOnline, presentation: presentation)
        applyActions(presentation)
        header.info.apply(
            [
                ProfileInfoCard.Row(value: peer.phone, key: strings.profilePhone, isAccent: false),
                ProfileInfoCard.Row(value: peer.username, key: strings.profileUsername, isAccent: true),
                ProfileInfoCard.Row(value: peer.bio, key: strings.profileBio, isAccent: false),
            ],
            theme: theme
        )
        navigationBar.apply(title: peer.name, back: strings.profileBack, theme: theme)
        tabs.apply(theme)
        let titles = [strings.profileMedia, strings.profileFiles, strings.profileLinks, strings.profileVoice]
        tabs.setTabs(titles.map { title in
            LiquidTab(title: title)
        })
        tabs.select(pager.selectedIndex, animated: false)
        mediaPane.node.backgroundColor = theme.colors.background
        mediaPane.grid.setAccessibilityLabels(strings.profilePhoto)
        applyLists(presentation)
        monthFormatter.locale = strings.pack.locale
        monthFormatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        monthPill.font = theme.fonts.caption
        monthPill.layer.cornerRadius = ceil(theme.fonts.caption.lineHeight + 8) / 2
        view.setNeedsLayout()
    }

    private func bindPaging() {
        pager.onPosition = { [weak self] position in
            self?.tabs.setPosition(position)
        }
        pager.onSelect = { [weak self] index in
            self?.tabs.select(index, animated: true)
            self?.monthPill.alpha = 0
        }
        tabs.onSelect = { [weak self] index in
            self?.pager.select(index, animated: true)
        }
        mediaPane.onOffsetChange = { [weak self] in
            self?.updateMonthPill()
        }
        mediaPane.grid.pinch.addTarget(self, action: #selector(mediaPinched(_:)))
    }

    private func bindHeader() {
        container.onChange = { [weak self] in
            self?.containerChanged()
        }
        header.onPhotoTap = { [weak self] forward in
            self?.photoTapped(forward: forward)
        }
        header.onAction = { [weak self] action, button in
            self?.perform(action, from: button)
        }
        navigationBar.backButton.addAction(
            UIAction { [router] _ in
                router.back()
            },
            for: .touchUpInside
        )
    }

    private func applyLists(_ presentation: PresentationData) {
        let theme = presentation.theme
        let listTheme = ListTheme(
            background: theme.colors.background,
            rowBackground: theme.colors.background,
            primary: theme.colors.textPrimary,
            secondary: theme.colors.textSecondary,
            separator: theme.colors.separator,
            accent: theme.colors.accent,
            titleFont: theme.fonts.body,
            subtitleFont: theme.fonts.subheadline
        )
        for (pane, kind) in zip(listPanes, ProfileAttachmentItem.Kind.allCases) {
            pane.list.theme = listTheme
            let items = ProfileAttachments.items(kind, strings: presentation.strings) { [weak self] title in
                self?.showToast(title, symbol: "doc")
            }
            pane.list.apply(items: items, animated: false)
        }
    }

    @objc
    private func mediaPinched(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            container.stopMotion()
        }
    }
}
