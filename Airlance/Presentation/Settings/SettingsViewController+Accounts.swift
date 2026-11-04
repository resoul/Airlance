import AirlanceUI
import UIKit

extension SettingsViewController {
    func accountRows() -> [SettingsRowItem] {
        let strings = presentation.strings
        let switcher = accounts
        let current = switcher.currentAccountID
        var rows = switcher.accountRecords.map { record in
            accountRow(record, isCurrent: record.id == current)
        }
        rows.append(SettingsRowItem(
            id: "account-sign-in",
            title: strings.authAddAccount,
            symbol: "person.badge.plus",
            color: .systemBlue,
            position: .middle,
            onSelect: {
                switcher.addAccount()
            }
        ))
        rows.append(SettingsRowItem(
            id: "account-add",
            title: strings.accountAdd,
            symbol: "plus",
            color: .systemBlue,
            position: .middle,
            onSelect: {
                switcher.addDemoAccount()
            }
        ))
        if let current, let record = switcher.accountRecords.first(where: { record in
            record.id == current
        }) {
            rows.append(removeRow(record))
        }

        return rows
    }

    private func removeRow(_ record: AccountRecord) -> SettingsRowItem {
        let strings = presentation.strings

        return SettingsRowItem(
            id: "account-remove",
            title: record.isDemo ? strings.accountRemove : strings.authSignOut,
            symbol: record.isDemo ? "trash" : "rectangle.portrait.and.arrow.right",
            color: .systemRed,
            position: .middle,
            onSelect: { [weak self] in
                self?.confirmRemove(record)
            }
        )
    }

    private func accountRow(_ record: AccountRecord, isCurrent: Bool) -> SettingsRowItem {
        let strings = presentation.strings
        let switcher = accounts
        let id = record.id
        let marks = [record.isDemo ? strings.accountDemo : nil, isCurrent ? strings.accountCurrent : nil]

        return SettingsRowItem(
            id: "account-\(id.rawValue)",
            title: isCurrent ? myProfile.profile.fullName : strings.accountName(record),
            symbol: isCurrent ? "person.crop.circle.badge.checkmark" : "person.crop.circle",
            color: isCurrent ? .systemGreen : .systemGray,
            detail: marks.compactMap(\.self).joined(separator: " · "),
            position: .middle,
            onSelect: {
                switcher.switchAccount(to: id)
            }
        )
    }

    private func confirmRemove(_ record: AccountRecord) {
        let strings = presentation.strings
        let switcher = accounts
        PopupAlert.show(
            title: nil,
            message: record.isDemo
                ? strings.accountRemoveConfirm(strings.accountName(record))
                : strings.authSignOutConfirm(strings.accountName(record)),
            actions: [
                PopupAlertAction(
                    title: record.isDemo ? strings.accountRemoveAction : strings.authSignOutAction,
                    style: .destructive
                ) {
                    switcher.removeAccount(record.id)
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }
}
