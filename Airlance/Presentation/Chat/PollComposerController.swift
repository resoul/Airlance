import ChatHistory
import UIKit

final class PollComposerController: UITableViewController {
    enum Section: Int, CaseIterable {
        case question
        case options
        case settings
        case explanation
    }

    enum Limit: CaseIterable {
        case never
        case minutes
        case hour
        case day

        var interval: TimeInterval? {
            switch self {
            case .never:
                nil
            case .minutes:
                300
            case .hour:
                3600
            case .day:
                86400
            }
        }
    }

    private static let maxOptions = 10

    var onCreate: (@MainActor (MessagePoll) -> Void)?

    let presentation: PresentationData
    var question = ""
    var options = ["", ""]
    var explanation = ""
    var isAnonymous = true
    var allowsMultiple = false
    var isQuiz = false
    var correctIndex: Int?
    var limit = Limit.never

    init(presentation: PresentationData) {
        self.presentation = presentation
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let strings = presentation.strings
        title = strings.pollNew
        tableView.backgroundColor = presentation.theme.colors.background
        tableView.keyboardDismissMode = .interactive
        tableView.register(PollFieldCell.self, forCellReuseIdentifier: "field")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: strings.pollCancel,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: strings.pollCreate,
            primaryAction: UIAction { [weak self] _ in
                self?.create()
            }
        )
        navigationItem.rightBarButtonItem?.style = .done
        updateCreate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? PollFieldCell)?.field.becomeFirstResponder()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        isQuiz ? Section.allCases.count : Section.allCases.count - 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .options:
            options.count
        case .settings:
            4
        default:
            1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let strings = presentation.strings
        switch Section(rawValue: section) {
        case .question:
            return strings.pollQuestion
        case .options:
            return strings.pollOptions
        case .settings:
            return strings.pollSettings
        default:
            return strings.pollExplanation
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Section(rawValue: section) == .options && isQuiz ? presentation.strings.pollQuizHint : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard Section(rawValue: indexPath.section) != .settings else {
            return settingCell(indexPath.row)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "field", for: indexPath)
        guard let field = cell as? PollFieldCell else {
            return cell
        }

        configure(field, at: indexPath)

        return field
    }

    private func configure(_ cell: PollFieldCell, at indexPath: IndexPath) {
        let strings = presentation.strings
        let section = Section(rawValue: indexPath.section)
        cell.apply(presentation)
        switch section {
        case .question:
            cell.field.placeholder = strings.pollQuestion
            cell.field.text = question
        case .options:
            cell.field.placeholder = strings.pollOption
            cell.field.text = options[indexPath.row]
        default:
            cell.field.placeholder = strings.pollExplanationHint
            cell.field.text = explanation
        }
        cell.setMarker(section == .options && isQuiz, isOn: correctIndex == indexPath.row)
        cell.onMark = { [weak self, weak cell] in
            guard let self, let cell, let path = self.tableView.indexPath(for: cell) else {
                return
            }

            self.markCorrect(path.row)
        }
        cell.onChange = { [weak self, weak cell] text in
            guard let self, let cell, let path = self.tableView.indexPath(for: cell) else {
                return
            }

            self.changed(text, at: path)
        }
        cell.onReturn = { [weak self, weak cell] in
            guard let self, let cell, let path = self.tableView.indexPath(for: cell) else {
                return
            }

            self.focusNext(after: path)
        }
    }

    private func changed(_ text: String, at path: IndexPath) {
        switch Section(rawValue: path.section) {
        case .question:
            question = text
        case .options:
            options[path.row] = text
            let isLast = path.row == options.count - 1
            if isLast, !text.isEmpty, options.count < Self.maxOptions {
                options.append("")
                tableView.insertRows(at: [IndexPath(row: options.count - 1, section: path.section)], with: .automatic)
            }
        default:
            explanation = text
        }
        updateCreate()
    }

    private func focusNext(after path: IndexPath) {
        let next = path.section == Section.question.rawValue
            ? IndexPath(row: 0, section: Section.options.rawValue)
            : IndexPath(row: path.row + 1, section: path.section)
        guard path.section != Section.explanation.rawValue,
              let cell = tableView.cellForRow(at: next) as? PollFieldCell else {
            view.endEditing(true)

            return
        }

        cell.field.becomeFirstResponder()
    }

    private func markCorrect(_ row: Int) {
        correctIndex = row
        for case let cell as PollFieldCell in tableView.visibleCells {
            if let path = tableView.indexPath(for: cell), path.section == Section.options.rawValue {
                cell.setMarker(true, isOn: path.row == row)
            }
        }
        updateCreate()
    }

    func updateCreate() {
        let hasQuestion = !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let filled = filledOptions
        let hasCorrect = !isQuiz || filled.contains { item in
            item.index == correctIndex
        }
        navigationItem.rightBarButtonItem?.isEnabled = hasQuestion && filled.count >= 2 && hasCorrect
    }

    private var filledOptions: [(index: Int, text: String)] {
        options.enumerated().compactMap { index, option in
            let text = option.trimmingCharacters(in: .whitespacesAndNewlines)

            return text.isEmpty ? nil : (index, text)
        }
    }

    private func create() {
        let filled = filledOptions
        var poll = MessagePoll(
            question: question.trimmingCharacters(in: .whitespacesAndNewlines),
            options: filled.map { item in
                MessagePoll.Option(text: item.text)
            },
            isAnonymous: isAnonymous,
            allowsMultiple: allowsMultiple && !isQuiz
        )
        if isQuiz {
            poll.correctOption = filled.firstIndex { item in
                item.index == correctIndex
            }
            let text = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            poll.explanation = text.isEmpty ? nil : text
        }
        poll.closeDate = limit.interval.map { interval in
            Date().addingTimeInterval(interval)
        }
        let onCreate = onCreate
        dismiss(animated: true) {
            onCreate?(poll)
        }
    }
}
