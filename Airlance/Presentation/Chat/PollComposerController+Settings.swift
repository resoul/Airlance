import UIKit

extension PollComposerController {
    func settingCell(_ row: Int) -> UITableViewCell {
        let strings = presentation.strings
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = presentation.theme.colors.surface
        cell.selectionStyle = .none
        cell.textLabel?.font = presentation.theme.fonts.body
        cell.textLabel?.textColor = presentation.theme.colors.textPrimary
        switch row {
        case 0:
            cell.textLabel?.text = strings.pollAnonymous
            cell.accessoryView = toggle(isAnonymous) { [weak self] isOn in
                self?.isAnonymous = isOn
            }
        case 1:
            cell.textLabel?.text = strings.pollMultipleTitle
            let toggle = toggle(allowsMultiple && !isQuiz) { [weak self] isOn in
                self?.allowsMultiple = isOn
            }
            toggle.isEnabled = !isQuiz
            cell.accessoryView = toggle
        case 2:
            cell.textLabel?.text = strings.pollQuizMode
            cell.accessoryView = toggle(isQuiz) { [weak self] isOn in
                self?.setQuiz(isOn)
            }
        default:
            cell.textLabel?.text = strings.pollLimit
            cell.accessoryView = limitButton()
        }

        return cell
    }

    private func toggle(_ isOn: Bool, onChange: @escaping @MainActor (Bool) -> Void) -> UISwitch {
        let toggle = UISwitch()
        toggle.onTintColor = presentation.theme.colors.accent
        toggle.isOn = isOn
        toggle.addAction(
            UIAction { [weak toggle] _ in
                onChange(toggle?.isOn ?? false)
            },
            for: .valueChanged
        )

        return toggle
    }

    private func setQuiz(_ isOn: Bool) {
        isQuiz = isOn
        view.endEditing(true)
        tableView.performBatchUpdates {
            let explanation = IndexSet(integer: Section.explanation.rawValue)
            if isOn {
                tableView.insertSections(explanation, with: .automatic)
            } else {
                tableView.deleteSections(explanation, with: .automatic)
            }
            tableView.reloadSections(IndexSet([Section.options.rawValue, Section.settings.rawValue]), with: .none)
        }
        updateCreate()
    }

    private func limitButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title(for: limit), for: .normal)
        button.titleLabel?.font = presentation.theme.fonts.body
        button.tintColor = presentation.theme.colors.accent
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: Limit.allCases.map { option in
            UIAction(title: title(for: option), state: option == limit ? .on : .off) { [weak self, weak button] _ in
                guard let self else {
                    return
                }

                self.limit = option
                button?.setTitle(self.title(for: option), for: .normal)
                button?.sizeToFit()
                self.tableView.reloadRows(
                    at: [IndexPath(row: 3, section: Section.settings.rawValue)],
                    with: .none
                )
            }
        })
        button.sizeToFit()

        return button
    }

    private func title(for limit: Limit) -> String {
        let strings = presentation.strings
        switch limit {
        case .never:
            return strings.pollLimitNever
        case .minutes:
            return strings.pollLimitMinutes
        case .hour:
            return strings.pollLimitHour
        case .day:
            return strings.pollLimitDay
        }
    }
}

final class PollFieldCell: UITableViewCell, UITextFieldDelegate {
    let field = UITextField()
    var onChange: (@MainActor (String) -> Void)?
    var onReturn: (@MainActor () -> Void)?
    var onMark: (@MainActor () -> Void)?

    private let marker = UIButton(type: .system)
    private var showsMarker = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        field.delegate = self
        field.returnKeyType = .next
        field.clearButtonMode = .whileEditing
        field.addAction(
            UIAction { [weak self] _ in
                self?.onChange?(self?.field.text ?? "")
            },
            for: .editingChanged
        )
        marker.addAction(
            UIAction { [weak self] _ in
                self?.onMark?()
            },
            for: .touchUpInside
        )
        contentView.addSubview(marker)
        contentView.addSubview(field)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        backgroundColor = presentation.theme.colors.surface
        field.font = presentation.theme.fonts.body
        field.textColor = presentation.theme.colors.textPrimary
        field.tintColor = presentation.theme.colors.accent
        marker.tintColor = .systemGreen
    }

    func setMarker(_ isShown: Bool, isOn: Bool) {
        showsMarker = isShown
        marker.isHidden = !isShown
        marker.setImage(UIImage(systemName: isOn ? "checkmark.circle.fill" : "circle"), for: .normal)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = contentView.bounds
        marker.frame = CGRect(x: 8, y: 0, width: 36, height: bounds.height)
        let x: CGFloat = showsMarker ? 46 : 16
        field.frame = CGRect(x: x, y: 0, width: bounds.width - x - 16, height: bounds.height)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturn?()

        return false
    }
}
