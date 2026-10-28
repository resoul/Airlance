import ChatFolders
import UIKit

extension FolderEditorViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let kind = sections[section]

        return kind == .included || kind == .excluded ? entries(kind).count : 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let strings = presentation.strings
        switch sections[section] {
        case .name:
            return strings.folderName
        case .included:
            return strings.folderIncluded
        case .excluded:
            return strings.folderExcluded
        case .color:
            return strings.folderColor
        case .delete:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let strings = presentation.strings
        switch sections[section] {
        case .included:
            return strings.folderIncludedFooter
        case .excluded:
            return strings.folderExcludedFooter
        case .color:
            return strings.folderColorFooter
        case .name, .delete:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        sections[indexPath.section] == .color ? 60 : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sections[indexPath.section]
        switch section {
        case .name:
            return nameCell
        case .color:
            return colorCell
        case .delete:
            return actionCell(at: indexPath, title: presentation.strings.folderDelete, symbol: nil, destructive: true)
        case .included, .excluded:
            return entryCell(entries(section)[indexPath.row], section: section, at: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = sections[indexPath.section]
        switch section {
        case .included, .excluded:
            if entries(section)[indexPath.row] == .add {
                openPicker(include: section == .included)
            }
        case .delete:
            confirmDelete()
        case .name, .color:
            break
        }
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let section = sections[indexPath.section]
        guard section == .included || section == .excluded else {
            return nil
        }

        let entry = entries(section)[indexPath.row]
        guard entry != .add else {
            return nil
        }

        let action = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, done in
            self?.remove(entry, from: section)
            done(true)
        }
        action.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [action])
    }

    private func entryCell(
        _ entry: FolderEditorEntry,
        section: FolderEditorSection,
        at indexPath: IndexPath
    ) -> UITableViewCell {
        let strings = presentation.strings
        switch entry {
        case .add:
            let title = section == .included ? strings.folderAddChats : strings.folderExcludeChats

            return actionCell(at: indexPath, title: title, symbol: "plus", destructive: false)
        case .category(let category):
            return labelCell(
                at: indexPath,
                title: strings.title(for: category),
                symbol: FolderStyle.symbol(for: category)
            )
        case .exclusion(let exclusion):
            return labelCell(
                at: indexPath,
                title: strings.title(for: exclusion),
                symbol: FolderStyle.symbol(for: exclusion)
            )
        case .chat(let id):
            return labelCell(at: indexPath, title: chatName(id), symbol: "bubble.left.fill")
        }
    }

    private func labelCell(at indexPath: IndexPath, title: String, symbol: String) -> UITableViewCell {
        let theme = presentation.theme
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.cell()
        content.text = title
        content.textProperties.font = theme.fonts.body
        content.textProperties.color = theme.colors.textPrimary
        content.image = UIImage(systemName: symbol)
        content.imageProperties.tintColor = theme.colors.textSecondary
        cell.contentConfiguration = content
        cell.backgroundColor = theme.colors.surface
        cell.selectionStyle = .none

        return cell
    }

    private func actionCell(
        at indexPath: IndexPath,
        title: String,
        symbol: String?,
        destructive: Bool
    ) -> UITableViewCell {
        let theme = presentation.theme
        let color = destructive ? theme.colors.destructive : theme.colors.accent
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.cell()
        content.text = title
        content.textProperties.font = theme.fonts.body
        content.textProperties.color = color
        content.textProperties.alignment = symbol == nil ? .center : .natural
        content.image = symbol.flatMap { name in
            UIImage(systemName: name)
        }
        content.imageProperties.tintColor = color
        cell.contentConfiguration = content
        cell.backgroundColor = theme.colors.surface
        cell.selectionStyle = .default

        return cell
    }
}
