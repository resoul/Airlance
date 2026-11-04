import AirlanceUI
import ChatHistory
import Haptics
import ToastUI
import UIKit

extension ChatViewController {
    func bindSend() {
        inputBar.onSendMenu = { [weak self] gesture in
            self?.trackSendMenu(gesture)
        }
        inputBar.onScheduled = { [weak self] in
            self?.scheduledTapped()
        }
        inputBar.onScheduledHold = { [weak self] in
            self?.scheduledHeld()
        }
        inputBar.onAttach = { [weak self] in
            self?.showAttachMenu()
        }
    }

    func updateScheduled() {
        let count = dependencies.historyStore.scheduledMessages(in: id).count
        let colors = presentation.theme.colors
        inputBar.setScheduledCount(count, tint: colors.textSecondary, label: presentation.strings.chatScheduled)
    }

    private func scheduledTapped() {
        if inputBar.hasText, !inputBar.isEditingMessage {
            pickScheduleDate()
        } else {
            showScheduledPopup()
        }
    }

    private func scheduledHeld() {
        if dependencies.historyStore.scheduledMessages(in: id).isEmpty {
            pickScheduleDate()
        } else {
            showScheduledPopup()
        }
    }

    private func trackSendMenu(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            showSendMenu()
        case .changed, .ended:
            activeSendMenu?.track(activeSendMenu?.location(of: gesture), ended: gesture.state == .ended)
        default:
            activeSendMenu?.track(nil, ended: true)
        }
        if gesture.state == .ended || gesture.state == .cancelled {
            activeSendMenu = nil
        }
    }

    private func showSendMenu() {
        guard let host = view.window else {
            return
        }

        let strings = presentation.strings
        let anchor = inputBar.convert(inputBar.actionIcon.frame, to: host)
        let items = [
            PopupMenuItem(title: strings.chatSendSilent, symbol: "bell.slash") { [weak self] in
                self?.sendSilently()
            },
            PopupMenuItem(title: strings.chatScheduleLater, symbol: "clock.arrow.circlepath") { [weak self] in
                self?.pickScheduleDate()
            },
            PopupMenuItem(title: strings.chatSendEffect, symbol: "sparkles") { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.showEffectMenu()
                }
            },
            PopupMenuItem(title: strings.chatSendTimer, symbol: "timer") { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.showLifetimeMenu()
                }
            },
        ]
        Haptics.play(.menu)
        activeSendMenu = PopupMenu.show(items, theme: presentation.theme, from: anchor, in: host)
    }

    private func showEffectMenu() {
        guard let host = view.window else {
            return
        }

        let strings = presentation.strings
        let anchor = inputBar.convert(inputBar.actionIcon.frame, to: host)
        let items = MessageEffect.allCases.compactMap { effect -> PopupMenuItem? in
            MessageEffectPlayer.image(for: effect.rawValue, size: 22).map { image in
                PopupMenuItem(title: effect.title(strings), image: image, isChecked: false) { [weak self] in
                    self?.sendWithEffect(effect)
                }
            }
        }
        PopupMenu.show(items, theme: presentation.theme, from: anchor, in: host, header: strings.chatSendEffect)
    }

    private func sendWithEffect(_ effect: MessageEffect) {
        send(ComposedText(attributed: inputBar.textView.attributedText), effect: effect.rawValue)
    }

    private func sendSilently() {
        send(ComposedText(attributed: inputBar.textView.attributedText), isSilent: true)
    }

    private func pickScheduleDate() {
        let peerName = dependencies.chatsStore.chat(peerID)?.name ?? ""
        let content = ScheduleSheetController(presentation: presentation, peerName: peerName)
        content.onPick = { [weak self] choice in
            self?.schedule(choice)
        }
        inputBar.dismissKeyboard()
        let sheet = FloatingSheetController(content: content, theme: presentation.theme) { _ in
            ScheduleSheetController.height
        }
        present(sheet, animated: false)
    }

    private func schedule(_ choice: ScheduleChoice) {
        let composed = ComposedText(attributed: inputBar.textView.attributedText)
        guard !composed.text.isEmpty else {
            return
        }

        let message = ScheduledMessage(
            id: UUID().uuidString,
            text: composed.text,
            date: choice.date,
            replyTo: replyTarget,
            quote: replyQuote,
            options: SendOptions(entities: composed.entities, isSilent: choice.isSilent),
            repeatRule: choice.repeatRule
        )
        dependencies.historyStore.schedule(message, in: id)
        cancelReply()
        inputBar.clear()
        updateScheduled()
        Haptics.play(.success)
        let text = presentation.strings.chatScheduledAt(scheduleFormatter.string(from: choice.date))
        Toast(text, symbol: "clock.arrow.circlepath").show(theme: presentation.theme, in: view)
    }

    var scheduleFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = presentation.strings.pack.locale
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        return formatter
    }
}
