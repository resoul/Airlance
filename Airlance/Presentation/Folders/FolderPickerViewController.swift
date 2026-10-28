import UIKit

struct FolderPickerOption {
    let id: String
    let title: String
    let symbol: String
}

final class FolderPickerViewController: ScreenViewController, UITableViewDataSource, UITableViewDelegate {
    var onDone: ((Set<String>) -> Void)?

    private let pickerTitle: String
    private let types: [FolderPickerOption]
    private let chats: [FolderPickerOption]
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var selected: Set<String>

    init(
        presentationSource: PresentationContext,
        title: String,
        types: [FolderPickerOption],
        chats: [FolderPickerOption],
        selected: Set<String>
    ) {
        pickerTitle = title
        self.types = types
        self.chats = chats
        self.selected = selected
        super.init(presentationSource: presentationSource)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        navigationItem.title = pickerTitle
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: presentation.strings.foldersDone,
            primaryAction: UIAction { [weak self] _ in
                self?.finish()
            }
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: presentation.strings.foldersCancel,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        tableView.backgroundColor = presentation.theme.colors.background
        tableView.separatorColor = presentation.theme.colors.separator
        tableView.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? types.count : chats.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? presentation.strings.folderChatTypes : presentation.strings.folderChats
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = indexPath.section == 0 ? types[indexPath.row] : chats[indexPath.row]
        let theme = presentation.theme
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.cell()
        content.text = option.title
        content.textProperties.font = theme.fonts.body
        content.textProperties.color = theme.colors.textPrimary
        content.image = UIImage(systemName: option.symbol)
        content.imageProperties.tintColor = theme.colors.textSecondary
        cell.contentConfiguration = content
        cell.backgroundColor = theme.colors.surface
        cell.tintColor = theme.colors.accent
        cell.accessoryType = selected.contains(option.id) ? .checkmark : .none

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = indexPath.section == 0 ? types[indexPath.row] : chats[indexPath.row]
        if selected.contains(option.id) {
            selected.remove(option.id)
        } else {
            selected.insert(option.id)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    private func finish() {
        onDone?(selected)
        dismiss(animated: true)
    }
}
