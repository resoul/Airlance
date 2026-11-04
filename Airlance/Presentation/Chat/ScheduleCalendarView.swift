import Haptics
import Theme
import UIKit

final class ScheduleCalendarView: UIView {
    private static let headerHeight: CGFloat = 44
    private static let weekdayHeight: CGFloat = 26
    private static let cellHeight: CGFloat = 44
    private static let cellCount = 42
    static let height = headerHeight + weekdayHeight + cellHeight * 6

    var onSelect: (@MainActor (Date) -> Void)?

    private let calendar: Calendar
    private let minimum: Date
    private let maximum: Date
    private let monthFormatter = DateFormatter()
    private let locale: Locale
    private let title = UILabel()
    private let previousMonth = UIButton(type: .system)
    private let nextMonth = UIButton(type: .system)
    private var weekdays: [UILabel] = []
    private var cells: [UIButton] = []
    private var cellDates: [Date?] = []
    private var month: Date
    private var selected: Date
    private var colors: ThemeColors?

    init(selected: Date, calendar: Calendar, locale: Locale) {
        self.calendar = calendar
        self.locale = locale
        self.selected = calendar.startOfDay(for: selected)
        minimum = calendar.startOfDay(for: Date())
        maximum = calendar.date(byAdding: .year, value: 1, to: minimum) ?? minimum
        month = Self.monthStart(of: selected, calendar: calendar)
        super.init(frame: .zero)
        monthFormatter.locale = locale
        monthFormatter.setLocalizedDateFormatFromTemplate("LLLLyyyy")
        addSubview(title)
        setupArrows()
        setupWeekdays()
        setupCells()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme) {
        colors = theme.colors
        title.font = theme.fonts.headline
        title.textColor = theme.colors.textPrimary
        previousMonth.tintColor = theme.colors.accent
        nextMonth.tintColor = theme.colors.accent
        for label in weekdays {
            label.font = theme.fonts.caption
            label.textColor = theme.colors.textSecondary
        }
        for cell in cells {
            cell.titleLabel?.font = theme.fonts.body
        }
        render()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        title.frame = CGRect(x: 8, y: 0, width: width - 100, height: Self.headerHeight)
        previousMonth.frame = CGRect(x: width - 88, y: 0, width: 44, height: Self.headerHeight)
        nextMonth.frame = CGRect(x: width - 44, y: 0, width: 44, height: Self.headerHeight)
        let cellWidth = width / 7
        for (index, label) in weekdays.enumerated() {
            let x = CGFloat(index) * cellWidth
            label.frame = CGRect(x: x, y: Self.headerHeight, width: cellWidth, height: Self.weekdayHeight)
        }
        let side = min(cellWidth, Self.cellHeight) - 3
        for (index, cell) in cells.enumerated() {
            let column = CGFloat(index % 7)
            let row = CGFloat(index / 7)
            let top = Self.headerHeight + Self.weekdayHeight
            cell.frame = CGRect(
                x: column * cellWidth + (cellWidth - side) / 2,
                y: top + row * Self.cellHeight + (Self.cellHeight - side) / 2,
                width: side,
                height: side
            )
            cell.layer.cornerRadius = side / 2
        }
    }

    private func setupArrows() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        previousMonth.setImage(UIImage(systemName: "chevron.left", withConfiguration: configuration), for: .normal)
        nextMonth.setImage(UIImage(systemName: "chevron.right", withConfiguration: configuration), for: .normal)
        previousMonth.addAction(
            UIAction { [weak self] _ in
                self?.shiftMonth(-1)
            },
            for: .touchUpInside
        )
        nextMonth.addAction(
            UIAction { [weak self] _ in
                self?.shiftMonth(1)
            },
            for: .touchUpInside
        )
        addSubview(previousMonth)
        addSubview(nextMonth)
    }

    private func setupWeekdays() {
        let symbols = monthFormatter.shortStandaloneWeekdaySymbols ?? []
        let first = calendar.firstWeekday - 1
        for index in symbols.indices {
            let label = UILabel()
            label.text = symbols[(index + first) % symbols.count].uppercased(with: locale)
            label.textAlignment = .center
            weekdays.append(label)
            addSubview(label)
        }
    }

    private func setupCells() {
        for index in 0..<Self.cellCount {
            let cell = UIButton(type: .custom)
            cell.addAction(
                UIAction { [weak self] _ in
                    self?.cellTapped(index)
                },
                for: .touchUpInside
            )
            cells.append(cell)
            addSubview(cell)
        }
    }

    private func shiftMonth(_ delta: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: delta, to: month) else {
            return
        }

        Haptics.play(.selection)
        month = shifted
        UIView.transition(with: self, duration: 0.18, options: .transitionCrossDissolve) {
            self.render()
        }
    }

    private func cellTapped(_ index: Int) {
        guard let date = cellDates[index] else {
            return
        }

        Haptics.play(.selection)
        selected = date
        render()
        onSelect?(date)
    }

    private func render() {
        title.text = monthFormatter.string(from: month).capitalized(with: locale)
        let offset = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        cellDates = (0..<Self.cellCount).map { index in
            let day = index - offset
            guard day >= 0, day < count else {
                return nil
            }

            return calendar.date(byAdding: .day, value: day, to: month)
        }
        for (index, cell) in cells.enumerated() {
            configure(cell, date: cellDates[index])
        }
        previousMonth.isEnabled = month > Self.monthStart(of: minimum, calendar: calendar)
        nextMonth.isEnabled = month < Self.monthStart(of: maximum, calendar: calendar)
    }

    private func configure(_ cell: UIButton, date: Date?) {
        guard let date, let colors else {
            cell.isHidden = true

            return
        }

        let isSelected = date == selected
        let isEnabled = date >= minimum && date <= maximum
        cell.isHidden = false
        cell.isEnabled = isEnabled
        cell.setTitle(String(calendar.component(.day, from: date)), for: .normal)
        cell.backgroundColor = isSelected ? colors.accent : .clear
        let color: UIColor
        if isSelected {
            color = colors.onAccent
        } else if !isEnabled {
            color = colors.textSecondary.withAlphaComponent(0.5)
        } else {
            color = date == minimum ? colors.accent : colors.textPrimary
        }
        cell.setTitleColor(color, for: .normal)
        cell.setTitleColor(color, for: .disabled)
    }

    private static func monthStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }
}
