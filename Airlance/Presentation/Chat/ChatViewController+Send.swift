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
            self?.showScheduled()
        }
        inputBar.onAttach = { [weak self] in
            self?.showAttachMenu()
        }
    }

    func updateScheduled() {
        let count = dependencies.historyStore.scheduledMessages(in: id).count
        let colors = presentation.theme.colors
        inputBar.setScheduledCount(count, tint: colors.accent, label: presentation.strings.chatScheduled)
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
            PopupMenuItem(title: strings.chatScheduleTitle, symbol: "calendar.badge.clock") { [weak self] in
                self?.pickScheduleDate()
            },
        ]
        Haptics.play(.menu)
        activeSendMenu = PopupMenu.show(items, theme: presentation.theme, from: anchor, in: host)
    }

    private func sendSilently() {
        send(ComposedText(attributed: inputBar.textView.attributedText), isSilent: true)
    }

    private func pickScheduleDate() {
        let sheet = ScheduleSheetController(presentation: presentation)
        if let controller = sheet.sheetPresentationController {
            controller.detents = [.medium()]
            controller.prefersGrabberVisible = true
        }
        sheet.onPick = { [weak self] date in
            self?.schedule(at: date)
        }
        present(sheet, animated: true)
    }

    private func schedule(at date: Date) {
        let composed = ComposedText(attributed: inputBar.textView.attributedText)
        guard !composed.text.isEmpty else {
            return
        }

        let message = ScheduledMessage(
            id: UUID().uuidString,
            text: composed.text,
            date: date,
            replyTo: replyTarget,
            quote: replyQuote,
            options: SendOptions(entities: composed.entities)
        )
        dependencies.historyStore.schedule(message, in: id)
        cancelReply()
        inputBar.clear()
        updateScheduled()
        Haptics.play(.success)
        let text = presentation.strings.chatScheduledAt(scheduleFormatter.string(from: date))
        Toast(text, symbol: "calendar.badge.clock").show(theme: presentation.theme, in: view)
    }

    private var scheduleFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = presentation.strings.pack.locale
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        return formatter
    }

    private func showScheduled() {
        guard let host = view.window else {
            return
        }

        let formatter = scheduleFormatter
        let items = dependencies.historyStore.scheduledMessages(in: id).map { message in
            let text = MessageEntity.masked(message.text, entities: message.options.entities)
                .replacingOccurrences(of: "\n", with: " ")
            let title = "\(formatter.string(from: message.date)) · \(text.prefix(28))"

            return PopupMenuItem(title: title, symbol: "clock") { [weak self] in
                self?.confirmScheduled(message)
            }
        }
        let anchor = inputBar.fieldBox.convert(inputBar.scheduledButton.frame, to: host)
        let header = presentation.strings.chatScheduled
        PopupMenu.show(items, theme: presentation.theme, from: anchor, in: host, header: header)
    }

    private func confirmScheduled(_ message: ScheduledMessage) {
        let strings = presentation.strings
        let store = dependencies.historyStore
        let chatID = id
        let actions = [
            PopupAlertAction(title: strings.chatScheduledSendNow) { [weak self] in
                store.sendScheduled(message.id, in: chatID)
                self?.updateScheduled()
            },
            PopupAlertAction(title: strings.chatScheduledDelete, style: .destructive) { [weak self] in
                store.cancelScheduled(message.id, in: chatID)
                self?.updateScheduled()
            },
            PopupAlertAction(title: strings.chatScheduledCancel, style: .cancel),
        ]
        let title = strings.chatScheduledAt(scheduleFormatter.string(from: message.date))
        PopupAlert.show(title: title, message: message.text, actions: actions, theme: presentation.theme, in: view)
    }
}
