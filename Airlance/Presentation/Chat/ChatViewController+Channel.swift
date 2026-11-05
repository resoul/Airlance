import ChatHistory
import Haptics
import Theme
import UIKit

extension ChatViewController {
    var thread: CommentThread? {
        CommentThread(id: id)
    }

    var peerID: String {
        thread?.channelID ?? id
    }

    func openComments(_ postID: String) {
        inputBar.dismissKeyboard()
        router.open(.comments(CommentThread(channelID: id, postID: postID).id))
    }

    var discussionGroupID: String? {
        thread.flatMap { thread in
            dependencies.historyStore.discussionGroup(of: thread)
        }
    }

    var discussionItem: UIBarButtonItem? {
        guard discussionGroupID != nil else {
            return nil
        }

        let item = UIBarButtonItem(
            image: UIImage(systemName: "person.2"),
            primaryAction: UIAction { [weak self] _ in
                self?.openDiscussionGroup()
            }
        )
        item.accessibilityLabel = presentation.strings.chatCommentsGroup

        return item
    }

    func openDiscussionGroup(focus messageID: String? = nil) {
        guard let group = discussionGroupID else {
            return
        }

        if let messageID {
            dependencies.historyStore.focusRequests[group] = messageID
        }
        inputBar.dismissKeyboard()
        router.open(.chat(group))
    }

    func showInGroupItems(for message: HistoryMessage) -> [MenuItem] {
        guard let thread, discussionGroupID != nil, ChatChannelFixtures.isComment(message, in: thread) else {
            return []
        }

        let item = MenuItem(
            title: presentation.strings.chatCommentsShowInGroup,
            symbol: "person.2",
            isDestructive: false,
            action: .run { [weak self] in
                self?.openDiscussionGroup(focus: message.id)
            }
        )

        return [item]
    }

    var canWrite: Bool {
        guard thread == nil, let chat = dependencies.chatsStore.chat(id) else {
            return true
        }

        if !chat.isMember, !dependencies.chatsStore.isJoined(id) {
            return false
        }

        return chat.kind != .channel || chat.canPost
    }

    func channelWallpaper(_ presentation: PresentationData) -> ThemeWallpaper? {
        let kind = dependencies.chatsStore.channelSettings.settings(peerID).wallpaper

        return kind?.resolved(for: presentation.theme.appearance)
    }

    func bindChannelSettings() {
        let channelID = peerID
        channelSettingsObservation = dependencies.chatsStore.channelSettings.observe { [weak self] changed in
            guard let self, changed == channelID else {
                return
            }

            self.apply(self.presentation)
        }
    }

    func bindForwardSources() {
        history.onOpenChat = { [weak self] chatID in
            guard let self, chatID != self.id, self.dependencies.chatsStore.chat(chatID) != nil else {
                return
            }

            Haptics.play(.tap)
            self.router.open(.chat(chatID))
        }
    }

    func placeChannelBar() {
        guard !canWrite else {
            return
        }

        inputBar.isHidden = true
        history.replySwipe.isEnabled = false
        channelBar.addAction(
            UIAction { [weak self] _ in
                guard let self else {
                    return
                }

                self.channelBarTapped()
            },
            for: .touchUpInside
        )
        view.addSubview(channelBar)
        let observation = dependencies.chatsStore.observe { [weak self] _ in
            self?.channelStateChanged()
        }
        storeObservations.append(observation)
    }

    private func channelStateChanged() {
        guard channelBar.superview != nil else {
            return
        }

        guard canWrite else {
            renderChannelBar(dependencies.chatsStore.chat(id), presentation: presentation)

            return
        }

        channelBar.removeFromSuperview()
        inputBar.isHidden = false
        history.replySwipe.isEnabled = true
        view.setNeedsLayout()
    }

    private func channelBarTapped() {
        let store = dependencies.chatsStore
        if store.chat(id)?.isServer == true, !store.isJoined(id) {
            joinServerChat()

            return
        }

        guard store.isJoined(id) else {
            store.subscribe(id)
            Haptics.play(.success)
            showToast(presentation.strings.chatChannelSubscribed, symbol: "checkmark.circle.fill")

            return
        }

        store.toggleMute(id)
    }

    private func joinServerChat() {
        let chatID = id
        let strings = presentation.strings
        let isGroup = dependencies.chatsStore.chat(id)?.kind == .group
        Task { [weak self] in
            do {
                try await self?.dependencies.chatsStore.joinOnServer(chatID)
                Haptics.play(.success)
                let text = isGroup ? strings.chatGroupJoined : strings.chatChannelSubscribed
                self?.showToast(text, symbol: "checkmark.circle.fill")
            } catch {
                self?.showToast(strings.newChatFailed, symbol: "exclamationmark.circle")
            }
        }
    }

    var bottomBarTop: CGFloat {
        if history.isSelecting {
            return selectionBar.frame.minY - 8
        }

        if history.search != nil {
            return searchBar.frame.minY - 8
        }

        return channelBar.superview == nil ? inputBar.frame.minY : channelBar.frame.minY - 8
    }

    func layoutChannelBar() {
        guard channelBar.superview != nil else {
            return
        }

        let height: CGFloat = 46
        let bottom = view.bounds.height - max(view.safeAreaInsets.bottom, 12)
        channelBar.frame = CGRect(x: 16, y: bottom - height, width: view.bounds.width - 32, height: height)
        channelBar.layer.cornerRadius = height / 2
    }

    func renderChannelBar(_ chat: ChatSummary?, presentation: PresentationData) {
        guard channelBar.superview != nil else {
            return
        }

        let theme = presentation.theme
        let strings = presentation.strings
        let isMuted = chat?.isMuted ?? false
        let isJoined = dependencies.chatsStore.isJoined(id)
        let muteTitle = isMuted ? strings.chatChannelUnmute : strings.chatChannelMute
        let joinTitle = chat?.kind == .group ? strings.chatGroupJoin : strings.chatChannelSubscribe
        let title = isJoined ? muteTitle : joinTitle
        channelBar.setTitle(title, for: .normal)
        channelBar.setTitleColor(isJoined ? theme.colors.accent : theme.colors.onAccent, for: .normal)
        channelBar.titleLabel?.font = theme.fonts.headline
        channelBar.backgroundColor = isJoined ? theme.colors.surface : theme.colors.accent
    }

    static func status(of chat: ChatSummary, strings: AppStrings) -> String {
        switch chat.kind {
        case .person:
            chat.isOnline ? strings.profileOnline : strings.profileLastSeen
        case .group:
            strings.count(
                chat.memberCount,
                one: strings.chatMembersOne,
                few: strings.chatMembersFew,
                many: strings.chatMembersMany
            )
        case .channel:
            strings.count(
                chat.memberCount,
                one: strings.chatSubscribersOne,
                few: strings.chatSubscribersFew,
                many: strings.chatSubscribersMany
            )
        }
    }
}
