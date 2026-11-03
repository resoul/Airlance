import UIKit

public final class SubtitleListController: UITableViewController {
    public var onChange: (@MainActor (Subtitles) -> Void)?
    public var onLanguage: (@MainActor (String) -> Void)?
    public var onAdd: (@MainActor () -> Void)?

    let strings: SubtitleStrings
    private(set) var language: String
    private(set) var subtitles: Subtitles

    public init(subtitles: Subtitles, language: String, strings: SubtitleStrings) {
        self.subtitles = subtitles
        self.language = language
        self.strings = strings
        super.init(style: .insetGrouped)
        title = strings.title
        overrideUserInterfaceStyle = .dark
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        let done = UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: done)
    }

    public func update(_ subtitles: Subtitles, language: String) {
        self.subtitles = subtitles
        self.language = language
        tableView.reloadData()
    }

    override public func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 3 : max(subtitles.phrases.count, 1)
    }

    override public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 ? (subtitles.isEmpty ? strings.empty : strings.hint) : nil
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.selectionStyle = .none
        guard indexPath.section == 1 else {
            return settingCell(cell, row: indexPath.row)
        }
        guard subtitles.phrases.indices.contains(indexPath.row) else {
            cell.textLabel?.text = strings.add
            cell.textLabel?.textColor = tableView.tintColor
            cell.selectionStyle = .default

            return cell
        }

        let phrase = subtitles.phrases[indexPath.row]
        let seconds = Int(phrase.start)
        cell.textLabel?.text = phrase.text
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
        cell.selectionStyle = .default

        return cell
    }

    override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else {
            return
        }
        guard subtitles.phrases.indices.contains(indexPath.row) else {
            onAdd?()

            return
        }

        edit(indexPath.row)
    }

    override public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 1 && subtitles.phrases.indices.contains(indexPath.row)
    }

    override public func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete, subtitles.phrases.indices.contains(indexPath.row) else {
            return
        }

        subtitles.phrases.remove(at: indexPath.row)
        onChange?(subtitles)
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }

    public func edit(_ index: Int) {
        let alert = UIAlertController(title: strings.edit, message: nil, preferredStyle: .alert)
        alert.addTextField { [subtitles] field in
            field.text = subtitles.phrases[index].text
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: strings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: strings.save, style: .default) { [weak self, weak alert] _ in
            self?.save(alert?.textFields?.first?.text ?? "", at: index)
        })
        present(alert, animated: true)
    }

    private func save(_ text: String, at index: Int) {
        guard subtitles.phrases.indices.contains(index) else {
            return
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            subtitles.phrases.remove(at: index)
        } else {
            subtitles.phrases[index].setText(text)
        }
        onChange?(subtitles)
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }
}
