import AirlanceUI
import ChatHistory
import Haptics
import UIKit

extension ChatViewController {
    func showScheduledPopup() {
        let store = dependencies.historyStore
        let chatID = id
        let popup = ChatMessagesPopupController(
            title: presentation.strings.chatScheduled,
            presentation: presentation,
            showsNames: false,
            startsAtBottom: false
        ) {
            store.scheduledPreviews(in: chatID)
        }
        popup.onSelect = { [weak self] messageID in
            self?.confirmScheduled(messageID)
        }
        popup.onHold = popup.onSelect
        showPopup(popup)
    }

    func showPinnedPopup() {
        let history = history
        let popup = ChatMessagesPopupController(
            title: presentation.strings.chatPinnedMessages,
            presentation: presentation,
            showsNames: thread != nil || dependencies.chatsStore.chat(id)?.kind == .group,
            startsAtBottom: true
        ) {
            history.pinnedIDs.compactMap { id in
                history.message(id)
            }
        }
        popup.onSelect = { [weak self, weak popup] messageID in
            popup?.floatingSheet?.close {
                self?.history.reveal(messageID)
            }
        }
        popup.onHold = { [weak self] messageID in
            self?.confirmPopupUnpin(messageID)
        }
        showPopup(popup)
    }

    private func showPopup(_ popup: ChatMessagesPopupController) {
        guard messagesPopup == nil else {
            return
        }

        inputBar.dismissKeyboard()
        Haptics.play(.menu)
        let sheet = FloatingSheetController(content: popup, theme: presentation.theme) { [weak popup] width in
            popup?.height(for: width) ?? 0
        }
        messagesPopup = popup
        present(sheet, animated: false)
    }

    private func confirmPopupUnpin(_ messageID: String) {
        guard let host = messagesPopup?.floatingSheet?.view else {
            return
        }

        let strings = presentation.strings
        PopupAlert.show(
            title: nil,
            message: strings.chatUnpinConfirm,
            actions: [
                PopupAlertAction(title: strings.chatUnpin, style: .destructive) { [weak self] in
                    self?.history.setPinned(false, messageID: messageID)
                    self?.messagesPopup?.reload()
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: host
        )
    }

    private func confirmScheduled(_ messageID: String) {
        let store = dependencies.historyStore
        let chatID = id
        let message = store.scheduledMessages(in: chatID).first { message in
            message.id == messageID
        }
        guard let message, let host = messagesPopup?.floatingSheet?.view else {
            return
        }

        let strings = presentation.strings
        let changed: @MainActor () -> Void = { [weak self] in
            self?.updateScheduled()
            self?.messagesPopup?.reload()
        }
        let actions = [
            PopupAlertAction(title: strings.chatScheduledSendNow) {
                store.sendScheduled(messageID, in: chatID)
                changed()
            },
            PopupAlertAction(title: strings.chatScheduledDelete, style: .destructive) {
                store.cancelScheduled(messageID, in: chatID)
                changed()
            },
            PopupAlertAction(title: strings.chatScheduledCancel, style: .cancel),
        ]
        let title = strings.chatScheduledAt(scheduleFormatter.string(from: message.date))
        PopupAlert.show(title: title, message: nil, actions: actions, theme: presentation.theme, in: host)
    }
}
