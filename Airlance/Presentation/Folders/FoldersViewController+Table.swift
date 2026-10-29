import ChatFolders
import UIKit

extension FoldersViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        isFailed ? 2 : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? slots.count + 1 : 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? presentation.strings.foldersSection : nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 && slots.count > 1 ? presentation.strings.foldersFooter : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let theme = presentation.theme
        var content = UIListContentConfiguration.valueCell()
        content.textProperties.font = theme.fonts.body
        content.textProperties.color = theme.colors.textPrimary
        content.secondaryTextProperties.font = theme.fonts.body
        content.secondaryTextProperties.color = theme.colors.textSecondary
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.selectionStyle = .default
        cell.backgroundColor = theme.colors.surface

        if indexPath.section == 1 {
            content.text = presentation.strings.foldersRetry
            content.textProperties.color = theme.colors.accent
            content.image = UIImage(systemName: "arrow.clockwise")
            content.imageProperties.tintColor = theme.colors.accent
        } else if indexPath.row == 0 {
            content.text = presentation.strings.foldersCreate
            content.textProperties.color = theme.colors.accent
            content.image = UIImage(systemName: "folder.badge.plus")
            content.imageProperties.tintColor = theme.colors.accent
        } else {
            configure(&content, cell: cell, slot: slots[indexPath.row - 1])
        }
        cell.contentConfiguration = content

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else {
            dependencies.chatFolders.retry()

            return
        }

        if indexPath.row == 0 {
            router.open(.newChatFolder)
        } else if case .folder(let folder) = slots[indexPath.row - 1] {
            router.open(.chatFolder(folder.id))
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0 && indexPath.row > 0
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0 && indexPath.row > 0
    }

    func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        guard indexPath.section == 0, indexPath.row > 0, case .folder = slots[indexPath.row - 1] else {
            return .none
        }

        return .delete
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete, case .folder(let folder) = slots[indexPath.row - 1] else {
            return
        }

        confirmDelete(folder)
    }

    func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt source: IndexPath,
        toProposedIndexPath proposed: IndexPath
    ) -> IndexPath {
        guard proposed.section == 0 else {
            return IndexPath(row: slots.count, section: 0)
        }

        return IndexPath(row: max(proposed.row, 1), section: 0)
    }

    func tableView(_ tableView: UITableView, moveRowAt source: IndexPath, to destination: IndexPath) {
        let slot = slots.remove(at: source.row - 1)
        slots.insert(slot, at: destination.row - 1)
        saveOrder()
    }

    private func configure(_ content: inout UIListContentConfiguration, cell: UITableViewCell, slot: Slot) {
        let theme = presentation.theme
        switch slot {
        case .all:
            content.text = presentation.strings.chatsFolderAll
            content.image = UIImage(systemName: "bubble.left.and.bubble.right.fill")
            content.imageProperties.tintColor = theme.colors.accent
            cell.selectionStyle = .none
        case .folder(let folder):
            let count = chatCount(for: folder)
            content.text = FolderStyle.title(folder)
            content.secondaryText = count == 0 ? presentation.strings.foldersEmpty : String(count)
            content.image = folder.emoji == nil ? UIImage(systemName: "folder.fill") : nil
            content.imageProperties.tintColor = FolderStyle.color(folder.color) ?? theme.colors.accent
            cell.accessoryType = .disclosureIndicator
        }
    }
}
