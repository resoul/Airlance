import UIKit

final class TimePickerController: UIViewController {
    var onDone: (@MainActor (Int) -> Void)?

    private let picker = UIDatePicker()
    private let minute: Int

    init(minute: Int, title: String) {
        self.minute = minute
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        let start = Calendar.current.startOfDay(for: Date())
        picker.date = start.addingTimeInterval(TimeInterval(minute * 60))
        view.addSubview(picker)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        picker.frame = view.bounds.inset(by: view.safeAreaInsets)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let components = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
        onDone?((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    static func text(_ minute: Int, locale: Locale) -> String {
        let start = Calendar.current.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short

        return formatter.string(from: start.addingTimeInterval(TimeInterval(minute * 60)))
    }
}
