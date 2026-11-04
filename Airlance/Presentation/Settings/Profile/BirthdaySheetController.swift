import Haptics
import UIKit

final class BirthdaySheetController: UIViewController {
    static let height: CGFloat = 72 + 216 + 16 + 50 + 8 + 44 + 16

    var onPick: (@MainActor (ProfileBirthday?) -> Void)?

    private let birthday: ProfileBirthday?
    private let presentation: PresentationData
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let picker = UIDatePicker()
    private let saveButton = UIButton(type: .system)
    private let removeButton = UIButton(type: .system)

    init(birthday: ProfileBirthday?, presentation: PresentationData) {
        self.birthday = birthday
        self.presentation = presentation
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupActions()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = presentation.strings.pack.locale
        picker.maximumDate = Date()
        picker.date = initialDate
        for subview in [closeButton, titleLabel, picker, saveButton, removeButton] as [UIView] {
            view.addSubview(subview)
        }
    }

    private func setupHeader() {
        let theme = presentation.theme
        let strings = presentation.strings
        titleLabel.text = strings.profileEditBirthday
        titleLabel.font = theme.fonts.headline
        titleLabel.textColor = theme.colors.textPrimary
        titleLabel.textAlignment = .center
        let symbol = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbol), for: .normal)
        closeButton.tintColor = theme.colors.textPrimary
        closeButton.backgroundColor = theme.colors.textSecondary.withAlphaComponent(0.14)
        closeButton.layer.cornerRadius = 22
        closeButton.accessibilityLabel = strings.chatCancel
        closeButton.addAction(
            UIAction { [weak self] _ in
                self?.floatingSheet?.close()
            },
            for: .touchUpInside
        )
    }

    private func setupActions() {
        let theme = presentation.theme
        let strings = presentation.strings
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = theme.colors.accent
        configuration.baseForegroundColor = theme.colors.onAccent
        configuration.background.cornerRadius = 25
        configuration.title = strings.profileEditSave
        saveButton.configuration = configuration
        saveButton.addAction(
            UIAction { [weak self] _ in
                self?.save()
            },
            for: .touchUpInside
        )
        removeButton.setTitle(strings.profileEditRemoveBirthday, for: .normal)
        removeButton.titleLabel?.font = theme.fonts.body
        removeButton.tintColor = .systemRed
        removeButton.isHidden = birthday == nil
        removeButton.addAction(
            UIAction { [weak self] _ in
                self?.finish(nil)
            },
            for: .touchUpInside
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        closeButton.frame = CGRect(x: 16, y: 14, width: 44, height: 44)
        titleLabel.frame = CGRect(x: 68, y: 14, width: width - 136, height: 44)
        picker.frame = CGRect(x: 16, y: 72, width: width - 32, height: 216)
        saveButton.frame = CGRect(x: 16, y: picker.frame.maxY + 16, width: width - 32, height: 50)
        removeButton.frame = CGRect(x: 16, y: saveButton.frame.maxY + 8, width: width - 32, height: 44)
    }

    private var initialDate: Date {
        guard let birthday else {
            return Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
        }

        let parts = DateComponents(year: birthday.year, month: birthday.month, day: birthday.day)

        return Calendar.current.date(from: parts) ?? Date()
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: picker.date)
        finish(ProfileBirthday(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1))
    }

    private func finish(_ value: ProfileBirthday?) {
        Haptics.play(.selection)
        floatingSheet?.close { [onPick] in
            onPick?(value)
        }
    }
}
