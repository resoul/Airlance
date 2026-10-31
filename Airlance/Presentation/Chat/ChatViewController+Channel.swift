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

    var canWrite: Bool {
        guard thread == nil, let chat = dependencies.chatsStore.chat(id), chat.kind == .channel else {
            return true
        }

        return chat.canPost
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

                self.dependencies.chatsStore.toggleMute(self.id)
            },
            for: .touchUpInside
        )
        view.addSubview(channelBar)
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
        channelBar.setTitle(isMuted ? strings.chatChannelUnmute : strings.chatChannelMute, for: .normal)
        channelBar.setTitleColor(theme.colors.accent, for: .normal)
        channelBar.titleLabel?.font = theme.fonts.headline
        channelBar.backgroundColor = theme.colors.surface
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
