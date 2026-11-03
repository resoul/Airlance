import Haptics
import UIKit

final class GroupRightsController: UITableViewController {
    var onSave: (@MainActor (Set<GroupRight>) -> Void)?

    private let rights: [GroupRight]
    private let hint: String
    private let presentation: PresentationData
    private var selected: Set<GroupRight>

    init(title: String, hint: String, rights: [GroupRight], selected: Set<GroupRight>, presentation: PresentationData) {
        self.rights = rights
        self.hint = hint
        self.presentation = presentation
        self.selected = selected
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let strings = presentation.strings
        let colors = presentation.theme.colors
        tableView.backgroundColor = colors.background
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "right")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: strings.chatCancel,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        let save = UIBarButtonItem(
            title: strings.groupSave,
            primaryAction: UIAction { [weak self] _ in
                self?.save()
            }
        )
        save.style = .done
        navigationItem.rightBarButtonItem = save
        navigationController?.navigationBar.tintColor = colors.accent
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rights.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        hint
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "right", for: indexPath)
        let right = rights[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = presentation.strings.title(for: right)
        content.textProperties.font = presentation.theme.fonts.body
        content.textProperties.color = presentation.theme.colors.textPrimary
        cell.contentConfiguration = content
        cell.backgroundColor = presentation.theme.colors.surface
        cell.selectionStyle = .none
        let toggle = UISwitch()
        toggle.isOn = selected.contains(right)
        toggle.onTintColor = presentation.theme.colors.accent
        toggle.addAction(
            UIAction { [weak self, weak toggle] _ in
                self?.set(right, isOn: toggle?.isOn ?? false)
            },
            for: .valueChanged
        )
        cell.accessoryView = toggle

        return cell
    }

    private func set(_ right: GroupRight, isOn: Bool) {
        if isOn {
            selected.insert(right)
        } else {
            selected.remove(right)
        }
        Haptics.play(.selection)
    }

    private func save() {
        onSave?(selected)
        Haptics.play(.success)
        dismiss(animated: true)
    }
}

extension AppStrings {
    func title(for right: GroupRight) -> String {
        switch right {
        case .sendMessages:
            groupRightSendMessages
        case .sendMedia:
            groupRightSendMedia
        case .addMembers:
            groupRightAddMembers
        case .pinMessages:
            groupRightPinMessages
        case .changeInfo:
            groupRightChangeInfo
        case .deleteMessages:
            groupRightDeleteMessages
        case .banUsers:
            groupRightBanUsers
        case .addAdmins:
            groupRightAddAdmins
        }
    }

    func title(for role: GroupRole) -> String? {
        switch role {
        case .owner:
            groupOwner
        case .admin:
            groupAdmin
        case .member:
            nil
        }
    }
}
