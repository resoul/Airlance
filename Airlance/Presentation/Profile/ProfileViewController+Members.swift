import Haptics
import ListUI
import UIKit

extension ProfileViewController {
    func applyMembers(_ presentation: PresentationData, theme listTheme: ListTheme) {
        guard let membersPane else {
            return
        }

        let strings = presentation.strings
        let store = dependencies.groupMembers
        let canManage = store.myRole(in: id) < .member
        membersPane.list.theme = listTheme
        var items: [any ListItem] = []
        if canManage {
            let allowed = store.permissions(in: id).count
            items.append(GroupMemberItem(
                member: nil,
                title: strings.groupPermissions,
                detail: "\(allowed) / \(GroupRight.memberRights.count)",
                badge: nil,
                symbol: "key.fill"
            ) { [weak self] in
                self?.editPermissions()
            })
        }
        for member in store.members(in: id) {
            items.append(GroupMemberItem(
                member: member,
                title: member.id == GroupMembersStore.me.id ? strings.chatYou : member.name,
                detail: member.isOnline ? strings.profileOnline : strings.profileLastSeen,
                badge: strings.title(for: member.role),
                symbol: nil
            ) { [weak self] in
                self?.memberTapped(member)
            })
        }
        membersPane.list.apply(items: items, animated: true)
    }

    private func memberTapped(_ member: GroupMember) {
        guard member.id != GroupMembersStore.me.id else {
            return
        }

        let strings = presentation.strings
        let myRole = dependencies.groupMembers.myRole(in: id)
        let sheet = UIAlertController(title: member.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: strings.groupOpenProfile, style: .default) { [weak self] _ in
            self?.router.open(.profile(member.id))
        })
        if myRole < member.role {
            for action in manageActions(member, strings: strings) {
                sheet.addAction(action)
            }
        }
        sheet.addAction(UIAlertAction(title: strings.chatCancel, style: .cancel))
        sheet.view.tintColor = presentation.theme.colors.accent
        Haptics.play(.tap)
        present(sheet, animated: true)
    }

    private func manageActions(_ member: GroupMember, strings: AppStrings) -> [UIAlertAction] {
        var actions: [UIAlertAction] = []
        let title = member.role == .admin ? strings.groupEditRights : strings.groupMakeAdmin
        actions.append(UIAlertAction(title: title, style: .default) { [weak self] _ in
            self?.editRights(of: member)
        })
        if member.role == .admin {
            actions.append(UIAlertAction(title: strings.groupRemoveAdmin, style: .default) { [weak self] _ in
                guard let self else {
                    return
                }

                self.dependencies.groupMembers.demote(member.id, in: self.id)
            })
        }
        actions.append(UIAlertAction(title: strings.groupRemoveMember, style: .destructive) { [weak self] _ in
            self?.confirmRemoval(of: member)
        })

        return actions
    }

    private func editRights(of member: GroupMember) {
        let strings = presentation.strings
        let rights = GroupRightsController(
            title: strings.groupAdminRights,
            hint: strings.groupAdminRightsHint(member.name),
            rights: GroupRight.adminRights,
            selected: member.role == .admin ? member.rights : GroupRight.defaultAdmin,
            presentation: presentation
        )
        rights.onSave = { [weak self] selected in
            guard let self else {
                return
            }

            self.dependencies.groupMembers.promote(member.id, rights: selected, in: self.id)
        }
        presentSheet(rights)
    }

    private func editPermissions() {
        let strings = presentation.strings
        let store = dependencies.groupMembers
        let rights = GroupRightsController(
            title: strings.groupPermissions,
            hint: strings.groupPermissionsHint,
            rights: GroupRight.memberRights,
            selected: store.permissions(in: id),
            presentation: presentation
        )
        rights.onSave = { [weak self] selected in
            guard let self else {
                return
            }

            store.setPermissions(selected, in: self.id)
        }
        presentSheet(rights)
    }

    private func confirmRemoval(of member: GroupMember) {
        let strings = presentation.strings
        let title = strings.groupRemoveConfirm(member.name)
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: strings.chatCancel, style: .cancel))
        alert.addAction(UIAlertAction(title: strings.groupRemoveMember, style: .destructive) { [weak self] _ in
            guard let self else {
                return
            }

            self.dependencies.groupMembers.remove(member.id, from: self.id)
            Haptics.play(.success)
            self.showToast(strings.groupRemoved(member.name), symbol: "person.fill.xmark")
        })
        present(alert, animated: true)
    }

    private func presentSheet(_ controller: UIViewController) {
        let navigation = UINavigationController(rootViewController: controller)
        navigation.sheetPresentationController?.detents = [.medium(), .large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        present(navigation, animated: true)
    }
}
