import AirlanceUI
import Haptics
import UIKit

extension ProfileViewController {
    func showMoreMenu(from button: UIView) {
        guard let host = view.window else {
            return
        }

        let anchor = button.convert(button.bounds, to: host)
        PopupMenu.show(moreItems(), theme: presentation.theme, from: anchor, in: host)
    }

    private func moreItems() -> [PopupMenuItem] {
        let strings = presentation.strings
        guard let chat, chat.kind == .channel else {
            return personItems()
        }

        if chat.canPost {
            let channelID = id
            let router = router

            return [
                PopupMenuItem(title: strings.channelSettingsTitle, symbol: "gearshape") {
                    router.open(.channelSettings(channelID, .main))
                },
            ]
        }

        var items: [PopupMenuItem] = []
        if chat.isPublic {
            items.append(PopupMenuItem(title: strings.chatReport, symbol: "exclamationmark.circle") { [weak self] in
                self?.showChannelReport()
            })
        }
        if dependencies.chatsStore.isJoined(id) {
            items.append(
                PopupMenuItem(
                    title: strings.channelSettingsLeave,
                    symbol: "rectangle.portrait.and.arrow.right",
                    isDestructive: true
                ) { [weak self] in
                    self?.confirmLeave()
                }
            )
        }

        return items
    }

    private func confirmLeave() {
        let strings = presentation.strings
        let store = dependencies.chatsStore
        let channelID = id
        PopupAlert.show(
            title: nil,
            message: strings.channelSettingsLeaveConfirm,
            actions: [
                PopupAlertAction(title: strings.channelSettingsLeave, style: .destructive) { [weak self] in
                    store.unsubscribe(channelID)
                    Haptics.play(.success)
                    self?.router.back()
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }

    private func showChannelReport() {
        let channelID = id
        let store = dependencies.chatsStore
        let content = ChannelReportController(
            title: presentation.strings.chatReportChannelTitle,
            presentation: presentation
        )
        content.onPick = { [weak self] _ in
            store.reportChannel(channelID)
            Haptics.play(.success)
            self?.showToast(self?.presentation.strings.chatReportSent ?? "", symbol: "checkmark.circle.fill")
        }
        let sheet = FloatingSheetController(content: content, theme: presentation.theme) { _ in
            ChannelReportController.height
        }
        present(sheet, animated: false)
    }
}
