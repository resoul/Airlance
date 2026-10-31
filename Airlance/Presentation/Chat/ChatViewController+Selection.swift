import AirlanceUI
import ChatHistory
import EffectsUI
import ToastUI
import UIKit

extension ChatViewController {
    func bindSelection() {
        selectionTitle.textAlignment = .center
        selectionBar.alpha = 0
        selectionBar.isHidden = true
        view.addSubview(selectionBar)
        history.onSelectionChange = { [weak self] selection in
            self?.selectionChanged(selection)
        }
        selectionBar.onDelete = { [weak self] in
            self?.deleteSelected()
        }
        selectionBar.onCopy = { [weak self] in
            self?.copySelected()
        }
        selectionBar.onForward = { [weak self] in
            self?.forwardSelected()
        }
    }

    func startSelecting(_ messageID: String) {
        endSearch()
        inputBar.dismissKeyboard()
        history.startSelecting(with: messageID)
    }

    func layoutSelectionBar() {
        let height = MessageSelectionBar.height
        let bottom = view.bounds.height - max(view.safeAreaInsets.bottom, 12)
        selectionBar.frame = CGRect(x: 16, y: bottom - height, width: view.bounds.width - 32, height: height)
    }

    func renderSelection(_ presentation: PresentationData) {
        selectionBar.apply(presentation)
        selectionTitle.font = presentation.theme.fonts.headline
        selectionTitle.textColor = presentation.theme.colors.textPrimary
        if let selection = history.selection {
            selectionTitle.text = presentation.strings.chatSelectedCount(String(selection.count))
            selectionTitle.sizeToFit()
        }
    }

    private func selectionChanged(_ selection: Set<String>?) {
        let isOn = selection != nil
        let messages = history.selectedMessages
        selectionBar.update(
            count: messages.count,
            canDelete: canWrite,
            canCopy: messages.contains { message in
                !message.content.text.isEmpty
            }
        )
        renderSelection(presentation)
        guard isOn != (navigationItem.titleView === selectionTitle) else {
            return
        }

        updateNavigation(selecting: isOn)
        history.replySwipe.isEnabled = !isOn && canWrite
        selectionBar.isHidden = false
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.selectionBar.alpha = isOn ? 1 : 0
            self.selectionBar.transform = isOn ? .identity : CGAffineTransform(translationX: 0, y: 40)
            for bar in [self.inputBar, self.channelBar] as [UIView] {
                bar.alpha = isOn ? 0 : 1
                bar.transform = isOn ? CGAffineTransform(translationX: 0, y: 40) : .identity
            }
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.selectionBar.isHidden = self.history.selection == nil
        }
    }

    private func updateNavigation(selecting: Bool) {
        navigationController?.interactivePopGestureRecognizer?.isEnabled = !selecting
        navigationItem.hidesBackButton = selecting
        navigationItem.titleView = selecting ? selectionTitle : titleView
        navigationItem.leftBarButtonItem = selecting ? UIBarButtonItem(
            title: presentation.strings.chatCancel,
            primaryAction: UIAction { [weak self] _ in
                self?.history.endSelecting()
            }
        ) : nil
        navigationItem.rightBarButtonItems = selecting ? [] : defaultRightItems
        selectionTitle.sizeToFit()
    }

    private func deleteSelected() {
        let messages = history.selectedMessages
        guard !messages.isEmpty else {
            return
        }

        let strings = presentation.strings
        let chat = dependencies.chatsStore.chat(peerID)
        var actions: [PopupAlertAction] = []
        if chat?.kind == .person, thread == nil {
            actions.append(deleteAction(strings.chatDeleteForBoth(chat?.name ?? ""), effect: .burn, messages: messages))
        } else if messages.allSatisfy(\.isOutgoing) {
            actions.append(deleteAction(strings.chatDeleteForEveryone, effect: .burn, messages: messages))
        }
        actions.append(deleteAction(strings.chatDeleteForMe, effect: .dissolve, messages: messages))
        actions.append(PopupAlertAction(title: strings.chatCancel, style: .cancel))
        PopupAlert.show(
            title: nil,
            message: strings.chatDeleteSelected(String(messages.count)),
            actions: actions,
            theme: presentation.theme,
            in: view
        )
    }

    private func deleteAction(
        _ title: String,
        effect: ViewEffects.Kind,
        messages: [HistoryMessage]
    ) -> PopupAlertAction {
        PopupAlertAction(title: title, style: .destructive) { [weak self] in
            guard let self else {
                return
            }

            for message in messages {
                let node = self.history.listView.node(for: message.id) as? MessageBubbleNode
                self.delete(message, node: node, effect: effect)
            }
            self.history.endSelecting()
        }
    }

    private func copySelected() {
        let text = history.selectedMessages
            .map(\.content.text)
            .filter { text in
                !text.isEmpty
            }
            .joined(separator: "\n\n")
        guard !text.isEmpty else {
            return
        }

        UIPasteboard.general.string = text
        history.endSelecting()
        Toast(presentation.strings.chatCopied, symbol: "doc.on.doc.fill").show(theme: presentation.theme, in: view)
    }

    private func forwardSelected() {
        let messages = history.selectedMessages
        guard !messages.isEmpty else {
            return
        }

        history.endSelecting()
        showForward(messages)
    }
}
