import AirlanceUI
@preconcurrency import AsyncDisplayKit
import AvatarUI
import LiquidUI
import ListUI
import Observers
import Protocol
import UIKit

struct ProfileDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
    let groupMembers: GroupMembersStore
    let onAir: OnAirStore
    var publicProfile: (@MainActor (String) async -> ProfileData?)?
    var serverContacts: ServerContactsStore?
    var privacy: PrivacyStore?
}

final class ProfileViewController: ScreenViewController {
    let id: String
    let dependencies: ProfileDependencies
    let chat: ChatSummary?
    let membersPane: ListPane?
    var peer: ProfilePeer
    var photos: [AvatarDescriptor]
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
    var audioObservation: ObservationToken?
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
    private lazy var tabsHost = FloatingTabsHost(tabs: tabs)
    private var savedPopGesture: Bool?
    private var membersObservation: ObservationToken?
    private static var didShowHint = false

    var mediaIndex: Int {
        membersPane == nil ? 0 : 1
    }

    init(id: String, dependencies: ProfileDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        self.router = router
        chat = dependencies.chatsStore.chat(id)
        membersPane = chat?.kind == .group ? ListPane(list: ListView(theme: ListTheme())) : nil
        peer = ProfilePeer(id: id, chat: chat)
        photos = peer.avatars
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindAudio()
        view.addSubview(container.view)
        pager.setTabsView(tabsHost, height: FloatingTabsHost.height)
        pager.overlaysTabs = true
        let members: [any ScrollablePane] = membersPane.map { pane in
            [pane]
        } ?? []
        pager.setPanes(members + [mediaPane] + listPanes)
        membersObservation = dependencies.groupMembers.observe { [weak self] event in
            guard let self, event.chatID == self.id else {
                return
            }

            self.applyLists(self.presentation)
        }
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
        loadServerProfile()
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !Self.didShowHint else {
            return
        }

        Self.didShowHint = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.view.window != nil else {
                return
            }

            self.showToast(self.presentation.strings.profileHint, symbol: "hand.draw")
        }
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
        mediaPane.topInset = FloatingTabsHost.height
        for pane in listPanes + (membersPane.map { pane in
            [pane]
        } ?? []) {
            pane.list.contentInsets.bottom = safe.bottom
            pane.list.contentInsets.top = FloatingTabsHost.height
        }
        updateHeaderHeight()
        layoutHeader()
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let strings = presentation.strings
        let theme = presentation.theme

        view.backgroundColor = theme.groupedBackground
        let status = chat.map { chat in
            chat.kind == .person ? nil : ChatViewController.status(of: chat, strings: strings)
        } ?? nil
        let personStatus = peer.isOnline ? strings.profileOnline : strings.profileLastSeen
        let shownStatus = status ?? personStatus
        header.apply(name: peer.name, status: shownStatus, isOnline: peer.isOnline, presentation: presentation)
        applyActions(presentation)
        header.info.apply(infoRows(strings), theme: theme)
        navigationBar.apply(title: peer.name, back: strings.profileBack, theme: theme)
        applyAudioPanel(theme)
        tabs.fillsWidth = true
        tabs.apply(theme)
        tabsHost.apply(theme)
        let members = membersPane == nil ? [] : [strings.profileMembers]
        let titles = members + [strings.profileMedia, strings.profileFiles, strings.profileLinks, strings.profileVoice]
        tabs.setTabs(titles.map { title in
            LiquidTab(title: title)
        })
        tabs.select(pager.selectedIndex, animated: false)
        mediaPane.node.backgroundColor = theme.groupedBackground
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
        header.onPhotoSwipe = { [weak self] forward in
            self?.photoSwiped(forward: forward)
        }
        header.onAction = { [weak self] action, button in
            self?.perform(action, from: button)
        }
        header.info.onCopy = { [weak self] text in
            self?.copyInfo(text)
        }
        navigationBar.backButton.addAction(
            UIAction { [router] _ in
                router.back()
            },
            for: .touchUpInside
        )
    }

    private func infoRows(_ strings: AppStrings) -> [ProfileInfoCard.Row] {
        guard chat?.kind == .person || chat == nil else {
            let settings = dependencies.chatsStore.channelSettings
            let about = settings.settings(id).about ?? peer.bio
            let link = settings.link(of: id)
            var rows = [ProfileInfoCard.Row(value: about, key: strings.groupDescription, isAccent: false)]
            if chat?.kind != .channel || chat?.isPublic == true {
                rows.append(ProfileInfoCard.Row(value: "airlance.app/\(link)", key: strings.groupLink, isAccent: true))
            }

            return rows
        }

        return [
            ProfileInfoCard.Row(value: peer.phone, key: strings.profilePhone, isAccent: false),
            ProfileInfoCard.Row(value: peer.username, key: strings.profileUsername, isAccent: true),
            ProfileInfoCard.Row(value: peer.bio, key: strings.profileBio, isAccent: false),
        ].filter { row in
            !row.value.isEmpty
        }
    }

    private func applyLists(_ presentation: PresentationData) {
        let theme = presentation.theme
        let listTheme = ListTheme(
            background: theme.groupedBackground,
            rowBackground: theme.groupedCell,
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
        applyMembers(presentation, theme: listTheme)
    }

    @objc
    private func mediaPinched(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            container.stopMotion()
        }
    }
}
