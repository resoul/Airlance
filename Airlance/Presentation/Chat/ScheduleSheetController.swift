import AirlanceUI
import Haptics
import UIKit

struct ScheduleChoice {
    let date: Date
    let isSilent: Bool
    let repeatRule: ScheduleRepeat
}

final class ScheduleSheetController: UIViewController {
    static let height: CGFloat = 72 + ScheduleCalendarView.height + 12 + rowHeight * 2 + 12 + 50 + 20
    private static let rowHeight: CGFloat = 56
    private static let side: CGFloat = 44
    private static let inset: CGFloat = 16

    var onPick: (@MainActor (ScheduleChoice) -> Void)?

    private let presentation: PresentationData
    private let peerName: String
    private let calendar: Calendar
    private let calendarView: ScheduleCalendarView
    private let closeButton = UIButton(type: .system)
    private let silentButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let timePicker = UIDatePicker()
    private let repeatLabel = UILabel()
    private let repeatButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private let separators = [UIView(), UIView()]
    private let formatter = DateFormatter()
    private var date: Date
    private var isSilent = false
    private var repeatRule = ScheduleRepeat.never

    init(presentation: PresentationData, peerName: String) {
        self.presentation = presentation
        self.peerName = peerName
        let locale = presentation.strings.pack.locale
        var calendar = Calendar(identifier: Calendar.current.identifier)
        calendar.locale = locale
        self.calendar = calendar
        let start = Date().addingTimeInterval(60)
        date = calendar.nextDate(after: start, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? start
        calendarView = ScheduleCalendarView(selected: date, calendar: calendar, locale: locale)
        super.init(nibName: nil, bundle: nil)
        formatter.locale = locale
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let subviews: [UIView] = [
            closeButton, titleLabel, silentButton, calendarView, timeLabel, timePicker, repeatLabel, repeatButton,
            sendButton,
        ] + separators
        for subview in subviews {
            view.addSubview(subview)
        }
        setupHeader()
        setupRows()
        calendarView.apply(presentation.theme)
        calendarView.onSelect = { [weak self] day in
            self?.dayChanged(day)
        }
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        render()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        let inset = Self.inset
        let side = Self.side
        closeButton.frame = CGRect(x: inset, y: 14, width: side, height: side)
        silentButton.frame = CGRect(x: width - inset - side, y: 14, width: side, height: side)
        titleLabel.frame = CGRect(x: inset + side, y: 14, width: width - (inset + side) * 2, height: side)
        let content = width - inset * 2
        calendarView.frame = CGRect(x: inset, y: 72, width: content, height: ScheduleCalendarView.height)
        let first = calendarView.frame.maxY + 12
        layoutRow(y: first, separator: separators[0], label: timeLabel, control: timePicker)
        let second = first + Self.rowHeight
        layoutRow(y: second, separator: separators[1], label: repeatLabel, control: repeatButton)
        sendButton.frame = CGRect(x: inset, y: second + Self.rowHeight + 12, width: content, height: 50)
    }

    private func layoutRow(y: CGFloat, separator: UIView, label: UILabel, control: UIView) {
        let width = view.bounds.width
        let inset = Self.inset + 8
        separator.frame = CGRect(x: inset, y: y, width: width - inset * 2, height: 0.5)
        label.frame = CGRect(x: inset, y: y, width: 140, height: Self.rowHeight)
        let size = control.sizeThatFits(CGSize(width: 220, height: 36))
        let controlWidth = min(size.width + (control === repeatButton ? 4 : 0), 220)
        control.frame = CGRect(
            x: width - inset - controlWidth,
            y: y + (Self.rowHeight - 36) / 2,
            width: controlWidth,
            height: 36
        )
    }

    private func setupHeader() {
        let theme = presentation.theme
        let colors = theme.colors
        let chip = colors.textSecondary.withAlphaComponent(0.14)
        titleLabel.text = presentation.strings.chatScheduleTitle
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = colors.textPrimary
        titleLabel.textAlignment = .center
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        closeButton.accessibilityLabel = presentation.strings.chatCancel
        closeButton.addAction(
            UIAction { [weak self] _ in
                self?.floatingSheet?.close()
            },
            for: .touchUpInside
        )
        silentButton.addAction(
            UIAction { [weak self] _ in
                self?.toggleSilent()
            },
            for: .touchUpInside
        )
        for button in [closeButton, silentButton] {
            button.tintColor = colors.textPrimary
            button.backgroundColor = chip
            button.layer.cornerRadius = Self.side / 2
        }
    }

    private func setupRows() {
        let theme = presentation.theme
        let colors = theme.colors
        let strings = presentation.strings
        for separator in separators {
            separator.backgroundColor = colors.separator
        }
        timeLabel.text = strings.chatScheduleTime
        repeatLabel.text = strings.chatScheduleRepeat
        for label in [timeLabel, repeatLabel] {
            label.font = theme.fonts.body
            label.textColor = colors.textPrimary
        }
        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .compact
        timePicker.locale = strings.pack.locale
        timePicker.tintColor = colors.accent
        timePicker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        var chip = UIButton.Configuration.plain()
        chip.background.backgroundColor = colors.textSecondary.withAlphaComponent(0.14)
        chip.background.cornerRadius = 18
        chip.baseForegroundColor = colors.textPrimary
        chip.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
        repeatButton.configuration = chip
        repeatButton.addAction(
            UIAction { [weak self] _ in
                self?.showRepeatMenu()
            },
            for: .touchUpInside
        )
        var send = UIButton.Configuration.filled()
        send.baseBackgroundColor = colors.accent
        send.baseForegroundColor = colors.onAccent
        send.background.cornerRadius = 25
        sendButton.configuration = send
    }

    private func render() {
        let symbol = isSilent ? "bell.slash" : "bell"
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        silentButton.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        silentButton.accessibilityLabel = presentation.strings.chatSendSilent
        timePicker.minimumDate = calendar.isDateInToday(date) ? Date().addingTimeInterval(60) : nil
        timePicker.date = date
        repeatButton.configuration?.title = repeatRule.title(presentation.strings)
        sendButton.configuration?.title = presentation.strings.chatScheduleSend(sendDateText)
        view.setNeedsLayout()
    }

    private var sendDateText: String {
        let text = formatter.string(from: date)
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        guard days <= 2 else {
            return text
        }

        return text.prefix(1).lowercased(with: presentation.strings.pack.locale) + text.dropFirst()
    }

    private func compose(day: Date, time: Date) -> Date {
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        let composed = calendar.date(
            bySettingHour: clock.hour ?? 12,
            minute: clock.minute ?? 0,
            second: 0,
            of: day
        ) ?? day

        return max(composed, Date().addingTimeInterval(60))
    }

    private func dayChanged(_ day: Date) {
        date = compose(day: day, time: date)
        render()
    }

    private func toggleSilent() {
        Haptics.play(.selection)
        isSilent.toggle()
        render()
        floatingSheet?.showHint(isSilent ? presentation.strings.chatScheduleSilentHint(peerName) : nil)
    }

    private func showRepeatMenu() {
        guard let host = view.window else {
            return
        }

        let items = ScheduleRepeat.allCases.map { rule in
            PopupMenuItem(title: rule.title(presentation.strings), symbol: rule.symbol) { [weak self] in
                self?.repeatRule = rule
                self?.render()
            }
        }
        let anchor = repeatButton.convert(repeatButton.bounds, to: host)
        PopupMenu.show(items, theme: presentation.theme, from: anchor, in: host)
    }

    @objc
    private func timeChanged() {
        date = compose(day: date, time: timePicker.date)
        render()
    }

    @objc
    private func sendTapped() {
        let choice = ScheduleChoice(
            date: max(date, Date().addingTimeInterval(5)),
            isSilent: isSilent,
            repeatRule: repeatRule
        )
        floatingSheet?.close { [onPick] in
            onPick?(choice)
        }
    }
}

extension ScheduleRepeat {
    fileprivate var symbol: String {
        switch self {
        case .never:
            return "nosign"
        case .daily:
            return "sun.max"
        case .weekly:
            return "calendar"
        case .biweekly:
            return "calendar.badge.clock"
        case .monthly:
            return "calendar.circle"
        }
    }

    fileprivate func title(_ strings: AppStrings) -> String {
        switch self {
        case .never:
            return strings.chatScheduleRepeatNever
        case .daily:
            return strings.chatScheduleRepeatDaily
        case .weekly:
            return strings.chatScheduleRepeatWeekly
        case .biweekly:
            return strings.chatScheduleRepeatBiweekly
        case .monthly:
            return strings.chatScheduleRepeatMonthly
        }
    }
}
