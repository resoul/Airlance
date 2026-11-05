import Protocol
import UIKit

struct AgentChatOption: Sendable, Equatable {
    let id: String
    let title: String
}

final class AgentFormView: UIScrollView {
    var onChange: (@MainActor () -> Void)?

    let nameField = UITextField()
    let keywordField = UITextField()
    let textView = UITextView()
    private let stack = UIStackView()
    private let chatButton = UIButton(type: .system)
    private let triggerButton = UIButton(type: .system)
    private let timePicker = UIDatePicker()
    private let daysStack = UIStackView()
    private let keywordCard = UIView()
    private let textTitle = UILabel()
    private let textHint = UILabel()
    private var dayButtons: [UIButton] = []
    private var chats: [AgentChatOption] = []
    private var strings: AppStrings?
    private(set) var chatID = ""
    private(set) var trigger = ServerAgentTrigger.joined
    private(set) var weekdays: Int32 = 127

    private var cards: [UIView] {
        [nameField, chatButton, triggerButton, keywordCard, timePicker, daysStack, textView]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        keyboardDismissMode = .interactive
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        keywordField.translatesAutoresizingMaskIntoConstraints = false
        keywordCard.addSubview(keywordField)
        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .compact
        daysStack.axis = .horizontal
        daysStack.distribution = .fillEqually
        daysStack.spacing = 4
        textView.isScrollEnabled = false
        textHint.numberOfLines = 0
        let rows: [UIView] = [
            nameField, chatButton, triggerButton, keywordCard, timePicker, daysStack, textTitle, textView, textHint,
        ]
        for row in rows {
            stack.addArrangedSubview(row)
        }
        layoutForm()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func layoutForm() {
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: frameLayoutGuide.trailingAnchor, constant: -16),
            nameField.heightAnchor.constraint(equalToConstant: 48),
            chatButton.heightAnchor.constraint(equalToConstant: 48),
            triggerButton.heightAnchor.constraint(equalToConstant: 48),
            keywordCard.heightAnchor.constraint(equalToConstant: 48),
            daysStack.heightAnchor.constraint(equalToConstant: 40),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110),
            keywordField.leadingAnchor.constraint(equalTo: keywordCard.leadingAnchor, constant: 14),
            keywordField.trailingAnchor.constraint(equalTo: keywordCard.trailingAnchor, constant: -14),
            keywordField.topAnchor.constraint(equalTo: keywordCard.topAnchor),
            keywordField.bottomAnchor.constraint(equalTo: keywordCard.bottomAnchor),
        ])
    }

    func fill(_ agent: ServerAgent, chats: [AgentChatOption]) {
        self.chats = chats
        nameField.text = agent.name
        keywordField.text = agent.keyword
        textView.text = agent.text
        chatID = agent.chatID.isEmpty ? chats.first?.id ?? "" : agent.chatID
        trigger = agent.trigger
        weekdays = agent.weekdays
        var parts = DateComponents()
        parts.hour = Int(agent.hour)
        parts.minute = Int(agent.minute)
        timePicker.date = Calendar.current.date(from: parts) ?? timePicker.date
    }

    func draft(from agent: ServerAgent) -> ServerAgent {
        var next = agent
        let parts = Calendar.current.dateComponents([.hour, .minute], from: timePicker.date)
        next.name = nameField.text ?? ""
        next.keyword = keywordField.text ?? ""
        next.text = textView.text ?? ""
        next.chatID = chatID
        next.trigger = trigger
        next.weekdays = weekdays
        next.hour = Int32(parts.hour ?? 9)
        next.minute = Int32(parts.minute ?? 0)
        next.timezone = TimeZone.current.identifier

        return next
    }

    func apply(_ presentation: PresentationData) {
        strings = presentation.strings
        let theme = presentation.theme
        backgroundColor = theme.groupedBackground
        for card in cards {
            card.backgroundColor = theme.groupedCell
            card.layer.cornerRadius = 12
            card.clipsToBounds = true
        }
        timePicker.backgroundColor = .clear
        daysStack.backgroundColor = .clear
        for field in [nameField, keywordField] {
            field.font = theme.fonts.body
            field.textColor = theme.colors.textPrimary
        }
        nameField.placeholder = presentation.strings.agentsName
        nameField.setLeftPadding(14)
        keywordField.placeholder = presentation.strings.agentsKeyword
        textView.font = theme.fonts.body
        textView.textColor = theme.colors.textPrimary
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textTitle.text = presentation.strings.agentsText
        textTitle.font = theme.fonts.caption
        textTitle.textColor = theme.colors.textSecondary
        textHint.font = theme.fonts.caption
        textHint.textColor = theme.colors.textSecondary
        rebuild(presentation)
    }

    private func rebuild(_ presentation: PresentationData) {
        let colors = presentation.theme.colors
        for button in [chatButton, triggerButton] {
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = presentation.theme.fonts.body
            button.setTitleColor(colors.accent, for: .normal)
            button.configuration = nil
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            button.showsMenuAsPrimaryAction = true
        }
        renderMenus(presentation.strings)
        renderDays(presentation)
        renderTrigger(presentation.strings)
    }

    private func renderMenus(_ strings: AppStrings) {
        let selected = chats.first { chat in
            chat.id == chatID
        }
        chatButton.setTitle(selected?.title ?? strings.agentsChat, for: .normal)
        chatButton.menu = UIMenu(children: chats.map { chat in
            UIAction(title: chat.title, state: chat.id == chatID ? .on : .off) { [weak self] _ in
                self?.chatID = chat.id
                self?.renderMenus(strings)
                self?.onChange?()
            }
        })
        triggerButton.setTitle(trigger.title(strings), for: .normal)
        triggerButton.menu = UIMenu(children: ServerAgentTrigger.allCases.map { option in
            UIAction(title: option.title(strings), state: option == trigger ? .on : .off) { [weak self] _ in
                self?.trigger = option
                self?.renderMenus(strings)
                self?.renderTrigger(strings)
                self?.onChange?()
            }
        })
    }

    private func renderTrigger(_ strings: AppStrings) {
        keywordCard.isHidden = trigger != .keyword
        timePicker.isHidden = trigger != .schedule
        daysStack.isHidden = trigger != .schedule
        switch trigger {
        case .webhook:
            textHint.text = strings.agentsHintWebhook
        case .schedule:
            textHint.text = nil
        case .joined, .keyword:
            textHint.text = strings.agentsHintName
        }
    }

    private func renderDays(_ presentation: PresentationData) {
        dayButtons.forEach { button in
            button.removeFromSuperview()
        }
        var calendar = Calendar.current
        calendar.locale = presentation.strings.pack.locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        dayButtons = (0..<symbols.count).map { offset in
            let day = (first + offset) % symbols.count
            let button = UIButton(type: .system)
            button.setTitle(symbols[day], for: .normal)
            button.titleLabel?.font = presentation.theme.fonts.subheadline
            button.layer.cornerRadius = 8
            button.tag = day
            paint(button, presentation: presentation)
            button.addAction(
                UIAction { [weak self, weak button] _ in
                    guard let self, let button else {
                        return
                    }

                    self.weekdays ^= Int32(1 << day)
                    self.paint(button, presentation: presentation)
                    self.onChange?()
                },
                for: .touchUpInside
            )
            daysStack.addArrangedSubview(button)

            return button
        }
    }

    private func paint(_ button: UIButton, presentation: PresentationData) {
        let colors = presentation.theme.colors
        let isOn = weekdays & Int32(1 << button.tag) != 0
        button.backgroundColor = isOn ? colors.accent : presentation.theme.groupedCell
        button.setTitleColor(isOn ? colors.onAccent : colors.textSecondary, for: .normal)
    }
}

private extension UITextField {
    func setLeftPadding(_ width: CGFloat) {
        leftView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 1))
        leftViewMode = .always
    }
}
