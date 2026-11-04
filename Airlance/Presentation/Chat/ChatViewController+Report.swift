import ChatHistory
import Haptics
import UIKit

extension ChatViewController {
    func menuReactions(for message: HistoryMessage) -> MessageMenuReactions? {
        let rule = dependencies.chatsStore.reactionRule(for: id)
        guard rule != .none else {
            return nil
        }

        return MessageMenuReactions(chosen: message.chosenReaction, allowed: rule.allowed) { [weak self] emoji in
            self?.history.react(emoji, messageID: message.id)
        }
    }

    var isCopyingRestricted: Bool {
        guard thread == nil, let chat = dependencies.chatsStore.chat(id), chat.kind == .channel, !chat.canPost else {
            return false
        }

        return dependencies.chatsStore.channelSettings.restrictsCopying(id)
    }

    func reportItems(for message: HistoryMessage) -> [MenuItem] {
        let store = dependencies.chatsStore
        guard
            thread == nil,
            let chat = store.chat(id),
            chat.kind == .channel,
            chat.isPublic,
            !chat.canPost,
            message.views != nil,
            !store.isPostReported(message.id)
        else {
            return []
        }

        let item = MenuItem(
            title: presentation.strings.chatReport,
            symbol: "exclamationmark.circle",
            isDestructive: false,
            action: .run { [weak self] in
                self?.showReport(for: message)
            }
        )

        return [item]
    }

    private func showReport(for message: HistoryMessage) {
        let store = dependencies.chatsStore
        let content = ChannelReportController(title: presentation.strings.chatReportTitle, presentation: presentation)
        content.onPick = { [weak self] _ in
            store.reportPost(message.id)
            Haptics.play(.success)
            self?.showToast(self?.presentation.strings.chatReportSent ?? "", symbol: "checkmark.circle.fill")
        }
        let sheet = FloatingSheetController(content: content, theme: presentation.theme) { _ in
            ChannelReportController.height
        }
        present(sheet, animated: false)
    }
}
