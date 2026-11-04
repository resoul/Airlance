import AirlanceUI
import CameraUI
import ChatHistory
import DeviceContacts
import MediaStore
import Observers
import UIKit

struct ChatDependencies {
    let presentationContext: PresentationContext
    let chatsStore: ChatsStore
    let historyStore: ChatHistoryStore
    let chatPositions: ChatScrollPositions
    let permissionFlow: PermissionFlow
    let videoNotes: VideoNoteSettings
    let media: MediaStore
    let translation: TranslationSettings
    let contacts: DeviceContactsStore
}

final class ChatViewController: ScreenViewController {
    let id: String
    let dependencies: ChatDependencies
    let router: AppRouter
    let titleView = ChatTitleView()
    let avatarButton = ChatAvatarButton()
    let avatarDrag = AvatarSearchDrag()
    var chatCamera: CameraSession?
    var cameraFlow: ChatCameraFlow?
    var isOpeningCamera = false
    let selectionBar = MessageSelectionBar()
    let selectionTitle = UILabel()
    let searchBar = ChatSearchBar()
    let searchField = UITextField()
    let wallpaper = ChatWallpaperView()
    var searchDebounce: Task<Void, Never>?
    let inputBar = ChatInputBar()
    let mentions = MentionSuggestionsView()
    let channelBar = UIButton(type: .system)
    let history: ChatHistoryController
    let translator = MessageTranslator()
    weak var activeMenu: MessageMenuView?
    weak var activeLinkMenu: PopupMenu?
    weak var activeSendMenu: PopupMenu?
    weak var messagesPopup: ChatMessagesPopupController?
    var channelSettingsObservation: ObservationToken?
    var replyTarget: HistoryMessage?
    var replyQuote: MessageQuote?
    var editTarget: HistoryMessage?
    var draftBeforeEdit: String?
    let pinnedBar = PinnedMessageBar()
    let translationBar = ChatTranslationBar()
    let topHeader = ChatHeaderParts()
    var chatLanguage: String?
    var isChatTranslated = false
    var isTranslationDismissed = false
    var messageLanguages: [String: String?] = [:]
    var chatTranslationTask: Task<Void, Never>?
    var isJumpingToPin = false
    weak var recorder: VoiceRecorderView?
    weak var videoNoteRecorder: VideoNoteRecorderView?
    var recorderStart = CGPoint.zero
    var filePreviewSource: FilePreviewSource?
    weak var metricsView: HistoryMetricsView?
    private var viewing: ObservationToken?
    private let scrollDown = ChatScrollDownButton()
    private var observation: ObservationToken?
    var expiryObservation: ObservationToken?

    init(id: String, dependencies: ChatDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        self.router = router
        history = ChatHistoryController(store: dependencies.historyStore, positions: dependencies.chatPositions)
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.titleView = titleView
        navigationItem.rightBarButtonItems = defaultRightItems
        for control in [titleView, avatarButton] as [UIControl] {
            control.addAction(
                UIAction { [weak self] _ in
                    self?.openProfile()
                },
                for: .touchUpInside
            )
        }
        avatarDrag.attach(to: avatarButton)
        avatarDrag.onSearch = { [weak self] in
            self?.startSearch()
        }
        view.addSubview(wallpaper)
        view.addSubview(history.listView.view)
        translator.attach(to: self)
        history.load(id, kind: thread == nil ? dependencies.chatsStore.chat(id)?.kind : .group)
        placeInputBar()
        placeChannelBar()
        placeScrollDown()
        placePinnedBar()
        placeTranslationBar()
        placeHeader()
        placeMetrics()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(quickReplyChanged(_:)),
            name: QuickReplyPresenter.replyingChanged,
            object: nil
        )
        inputBar.setText(dependencies.chatsStore.chat(id)?.draft ?? "", animated: false)
        observation = dependencies.chatsStore.observe { [weak self] _ in
            guard let self else {
                return
            }

            self.render(self.presentation)
        }
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        view.backgroundColor = presentation.theme.colors.background
        wallpaper.apply(channelWallpaper(presentation) ?? presentation.theme.chat.wallpaper)
        inputBar.apply(presentation)
        scrollDown.apply(presentation)
        history.apply(presentation)
        applyPinned(presentation)
        applyTranslationBar(presentation)
        applyHeader(presentation)
        render(presentation)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        wallpaper.frame = view.bounds
        layoutChannelBar()
        layoutSelectionBar()
        let list = history.listView
        list.frame = view.bounds
        list.contentInsets = UIEdgeInsets(
            top: view.safeAreaInsets.top + topBarsHeight + 4,
            left: 0,
            bottom: max(0, view.bounds.height - bottomBarTop) + 4,
            right: 0
        )
        history.setWidth(view.bounds.width)
        history.layoutChanged()
        layoutHeader()
        layoutMentions()
        let metricsOrigin = CGPoint(x: 8, y: view.safeAreaInsets.top + topBarsHeight + 8)
        metricsView?.place(at: metricsOrigin, maxWidth: view.bounds.width - 16)
        let size = ChatScrollDownButton.size
        scrollDown.frame = CGRect(
            x: view.bounds.width - 12 - size,
            y: bottomBarTop - 14 - size,
            width: size,
            height: size
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewing = dependencies.historyStore.view(id)
        history.metrics?.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewing = nil
        history.savePosition()
        history.metrics?.stop()
        dependencies.chatsStore.setDraft(editTarget == nil ? inputBar.text : draftBeforeEdit ?? "", for: id)
    }

    private func placeScrollDown() {
        view.addSubview(scrollDown)
        scrollDown.addAction(
            UIAction { [weak self] _ in
                self?.history.scrollToBottom()
            },
            for: .touchUpInside
        )
        history.onBottomState = { [weak self] isShown, unseen in
            self?.scrollDown.update(isShown: isShown, unseen: unseen)
        }
        history.onMessageMenu = { [weak self] message, node in
            self?.showMenu(for: message, node: node)
        }
        history.onPhotos = { [weak self] message, index, node in
            self?.showPhotos(of: message, at: index, node: node)
        }
        bindReply()
        bindSelection()
        bindSearch()
        bindSend()
        bindMentions()
        bindPolls()
        bindChannelSettings()
        bindVideoNotes()
        bindVoice()
        bindFailed()
        bindMessageActions()
        history.onOpenURL = { [weak self] url in
            self?.openLink(url)
        }
        history.onLinkMenu = { [weak self] url, node, point in
            self?.showLinkMenu(url, node: node, point: point)
        }
        history.listView.onLongPressMove = { [weak self] gesture in
            self?.trackMenu(gesture)
        }
    }

    private func placeInputBar() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)
        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
        if #available(iOS 17.0, *) {
            view.keyboardLayoutGuide.usesBottomSafeArea = false
        } else {
            inputBar.includesBottomSafeArea = false
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc
    private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        if !inputBar.frame.contains(gesture.location(in: view)) {
            inputBar.dismissKeyboard()
        }
    }

    private func render(_ presentation: PresentationData) {
        let strings = presentation.strings
        let peer = dependencies.chatsStore.chat(peerID)
        let chat = thread == nil ? peer : nil
        let name = thread == nil ? peer?.name ?? id : strings.chatCommentsTitle
        let isOnline = chat?.isOnline ?? false
        let typing = chat?.typing.map { name in
            strings.typing(name)
        }
        let status = typing ?? chat.map { chat in
            Self.status(of: chat, strings: strings)
        } ?? peer?.name
        let theme = presentation.theme
        titleView.apply(name: name, status: status, isOnline: isOnline, isTyping: typing != nil, theme: theme)
        renderChannelBar(chat, presentation: presentation)
        renderSelection(presentation)
        renderSearch(presentation)
        titleView.sizeToFit()
        avatarButton.apply(PeerAvatars.descriptor(id: peerID, name: peer?.name ?? name), label: strings.chatProfile)
    }

    @objc
    private func quickReplyChanged(_ notification: Notification) {
        guard let window = view.window, notification.object as AnyObject? === window else {
            return
        }

        let isReplying = notification.userInfo?[QuickReplyPresenter.isReplyingKey] as? Bool ?? false
        if isReplying {
            inputBar.dismissKeyboard()
        }
        UIView.animate(withDuration: 0.2) {
            self.inputBar.alpha = isReplying ? 0 : 1
            self.scrollDown.alpha = isReplying ? 0 : 1
        }
        inputBar.isUserInteractionEnabled = !isReplying
    }

    private func openProfile() {
        router.open(.profile(peerID))
    }
}
