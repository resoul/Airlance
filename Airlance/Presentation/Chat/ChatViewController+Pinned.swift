import AirlanceUI
import ChatHistory
import Haptics
import UIKit

extension ChatViewController {
    var pinnedHeight: CGFloat {
        history.pinnedIDs.isEmpty ? 0 : PinnedMessageBar.height
    }

    func placePinnedBar() {
        pinnedBar.isHidden = true
        pinnedBar.addTarget(self, action: #selector(pinnedTapped), for: .touchUpInside)
        pinnedBar.onUnpin = { [weak self] in
            self?.confirmUnpin()
        }
        view.addSubview(pinnedBar)
        history.onUpdate = { [weak self] in
            self?.updatePinned()
            self?.updateScheduled()
        }
    }

    func applyPinned(_ presentation: PresentationData) {
        let strings = presentation.strings
        pinnedBar.apply(
            presentation.theme,
            title: { current, total in
                total > 1 ? strings.chatPinnedCounter(current) : strings.chatPinned
            },
            unpinLabel: strings.chatUnpin
        )
    }

    func layoutPinnedBar() {
        pinnedBar.frame = CGRect(
            x: 0,
            y: view.safeAreaInsets.top,
            width: view.bounds.width,
            height: PinnedMessageBar.height
        )
    }

    func pinItem(for message: HistoryMessage) -> MenuItem {
        let strings = presentation.strings
        let isPinned = history.pinnedIDs.contains(message.id)

        return MenuItem(
            title: isPinned ? strings.chatUnpin : strings.chatPin,
            symbol: isPinned ? "pin.slash" : "pin",
            isDestructive: false,
            action: .run { [weak self] in
                self?.history.setPinned(!isPinned, messageID: message.id)
                Haptics.play(.success)
            }
        )
    }

    func updatePinned() {
        let ids = history.pinnedIDs
        let wasHidden = pinnedBar.isHidden
        pinnedBar.isHidden = ids.isEmpty
        if wasHidden != pinnedBar.isHidden {
            view.setNeedsLayout()
        }
        guard !ids.isEmpty, !isJumpingToPin else {
            return
        }

        let items = ids.map { id in
            PinnedMessageItem(id: id, text: history.message(id).map(snippet(of:)) ?? "")
        }
        var shown = ids.count - 1
        for (index, id) in ids.enumerated() where history.isAboveVisible(id) {
            shown = index
        }
        pinnedBar.setItems(items, showing: shown)
    }

    @objc
    private func pinnedTapped() {
        guard let item = pinnedBar.currentItem else {
            return
        }

        Haptics.play(.tap)
        isJumpingToPin = true
        history.reveal(item.id)
        let index = pinnedBar.current
        pinnedBar.show(index == 0 ? history.pinnedIDs.count - 1 : index - 1, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.isJumpingToPin = false
        }
    }

    private func confirmUnpin() {
        guard let item = pinnedBar.currentItem else {
            return
        }

        let strings = presentation.strings
        PopupAlert.show(
            title: nil,
            message: strings.chatUnpinConfirm,
            actions: [
                PopupAlertAction(title: strings.chatUnpin, style: .destructive) { [weak self] in
                    self?.history.setPinned(false, messageID: item.id)
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }
}
