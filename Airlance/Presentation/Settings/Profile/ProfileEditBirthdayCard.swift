import Haptics
import Theme
import UIKit

final class ProfileEditBirthdayCard: UIView {
    private static let rowHeight: CGFloat = 56
    private static let pickerHeight: CGFloat = 216
    private static let removeHeight: CGFloat = 52

    var onToggle: (@MainActor () -> Void)?
    var onChange: (@MainActor (ProfileBirthday) -> Void)?
    var onRemove: (@MainActor () -> Void)?

    private let row = UIControl()
    private let iconBackground = UIView()
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let picker = UIDatePicker()
    private let removeButton = UIButton(type: .system)
    private let topSeparator = UIView()
    private let bottomSeparator = UIView()
    private var isExpanded = false

    static func height(isExpanded: Bool) -> CGFloat {
        isExpanded ? rowHeight + pickerHeight + removeHeight : rowHeight
    }

    init(strings: AppStrings, theme: AppTheme) {
        super.init(frame: .zero)
        backgroundColor = theme.colors.surface
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        clipsToBounds = true
        iconBackground.backgroundColor = .systemBlue
        iconBackground.layer.cornerRadius = 8
        iconBackground.layer.cornerCurve = .continuous
        iconBackground.isUserInteractionEnabled = false
        let symbol = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.image = UIImage(systemName: "birthday.cake.fill", withConfiguration: symbol)
        icon.tintColor = .white
        icon.contentMode = .center
        icon.isUserInteractionEnabled = false
        titleLabel.text = strings.profileEditBirthday
        titleLabel.font = theme.fonts.body
        titleLabel.textColor = theme.colors.textPrimary
        titleLabel.isUserInteractionEnabled = false
        valueLabel.font = theme.fonts.body
        valueLabel.textAlignment = .right
        valueLabel.isUserInteractionEnabled = false
        topSeparator.backgroundColor = theme.colors.separator
        bottomSeparator.backgroundColor = theme.colors.separator
        setupControls(strings: strings, theme: theme)
        for subview in [iconBackground, icon, titleLabel, valueLabel] as [UIView] {
            row.addSubview(subview)
        }
        for subview in [row, picker, removeButton, topSeparator, bottomSeparator] as [UIView] {
            addSubview(subview)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupControls(strings: AppStrings, theme: AppTheme) {
        row.addAction(
            UIAction { [weak self] _ in
                self?.onToggle?()
            },
            for: .touchUpInside
        )
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = strings.pack.locale
        picker.maximumDate = Date()
        picker.addAction(
            UIAction { [weak self] _ in
                self?.pickerChanged()
            },
            for: .valueChanged
        )
        removeButton.setTitle(strings.profileEditRemoveBirthday, for: .normal)
        removeButton.titleLabel?.font = theme.fonts.body
        removeButton.tintColor = theme.colors.accent
        removeButton.contentHorizontalAlignment = .leading
        removeButton.addAction(
            UIAction { [weak self] _ in
                self?.onRemove?()
            },
            for: .touchUpInside
        )
    }

    func apply(birthday: ProfileBirthday?, text: String, isExpanded: Bool, theme: AppTheme) {
        let opens = isExpanded && !self.isExpanded
        self.isExpanded = isExpanded
        valueLabel.text = text
        valueLabel.textColor = isExpanded ? theme.colors.accent : theme.colors.textSecondary
        if opens, let birthday, let date = Self.date(of: birthday) {
            picker.setDate(date, animated: false)
        }
        setNeedsLayout()
    }

    func setValue(_ text: String) {
        valueLabel.text = text
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        row.frame = CGRect(x: 0, y: 0, width: width, height: Self.rowHeight)
        iconBackground.frame = CGRect(x: 14, y: (Self.rowHeight - 30) / 2, width: 30, height: 30)
        icon.frame = iconBackground.frame
        valueLabel.frame = CGRect(x: width / 2, y: 0, width: width / 2 - 18, height: Self.rowHeight)
        titleLabel.frame = CGRect(x: 58, y: 0, width: width / 2 - 58, height: Self.rowHeight)
        topSeparator.frame = CGRect(x: 58, y: Self.rowHeight, width: width - 58, height: 0.5)
        picker.frame = CGRect(x: 8, y: Self.rowHeight, width: width - 16, height: Self.pickerHeight)
        let removeY = picker.frame.maxY
        bottomSeparator.frame = CGRect(x: 18, y: removeY, width: width - 18, height: 0.5)
        removeButton.frame = CGRect(x: 18, y: removeY, width: width - 36, height: Self.removeHeight)
        for subview in [picker, removeButton, topSeparator, bottomSeparator] as [UIView] {
            subview.isHidden = !isExpanded
        }
    }

    private func pickerChanged() {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: picker.date)
        Haptics.play(.selection)
        onChange?(ProfileBirthday(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1))
    }

    private static func date(of birthday: ProfileBirthday) -> Date? {
        let parts = DateComponents(year: birthday.year, month: birthday.month, day: birthday.day)

        return Calendar.current.date(from: parts)
    }
}
