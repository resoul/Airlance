import UIKit

final class ScheduleSheetController: UIViewController {
    var onPick: (@MainActor (Date) -> Void)?

    private let presentation: PresentationData
    private let titleLabel = UILabel()
    private let picker = UIDatePicker()
    private let sendButton = UIButton(type: .system)
    private let formatter = DateFormatter()

    init(presentation: PresentationData) {
        self.presentation = presentation
        super.init(nibName: nil, bundle: nil)
        formatter.locale = presentation.strings.pack.locale
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
        let colors = presentation.theme.colors
        view.backgroundColor = colors.background
        titleLabel.text = presentation.strings.chatScheduleTitle
        titleLabel.font = presentation.theme.fonts.headline
        titleLabel.textColor = colors.textPrimary
        titleLabel.textAlignment = .center
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .wheels
        picker.locale = presentation.strings.pack.locale
        picker.minimumDate = Date().addingTimeInterval(60)
        picker.date = Date().addingTimeInterval(3600)
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = colors.accent
        configuration.baseForegroundColor = colors.onAccent
        configuration.cornerStyle = .large
        sendButton.configuration = configuration
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        for subview in [titleLabel, picker, sendButton] as [UIView] {
            view.addSubview(subview)
        }
        dateChanged()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        titleLabel.frame = CGRect(x: 16, y: 20, width: width - 32, height: 24)
        picker.frame = CGRect(x: 16, y: titleLabel.frame.maxY + 8, width: width - 32, height: 216)
        sendButton.frame = CGRect(x: 16, y: picker.frame.maxY + 12, width: width - 32, height: 50)
    }

    @objc
    private func dateChanged() {
        sendButton.configuration?.title = presentation.strings.chatScheduleSend(formatter.string(from: picker.date))
    }

    @objc
    private func sendTapped() {
        let date = max(picker.date, Date().addingTimeInterval(5))
        dismiss(animated: true) { [onPick] in
            onPick?(date)
        }
    }
}
