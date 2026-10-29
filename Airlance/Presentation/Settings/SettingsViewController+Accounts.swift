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
            rows.append(SettingsRowItem(
                id: "account-remove",
                title: strings.accountRemove,
                symbol: "trash",
                color: .systemRed,
                position: .middle,
                onSelect: { [weak self] in
                    self?.confirmRemove(record)
                }
            ))
        }

        return rows
    }

    private func accountRow(_ record: AccountRecord, isCurrent: Bool) -> SettingsRowItem {
        let strings = presentation.strings
        let switcher = accounts
        let id = record.id
        let marks = [record.isDemo ? strings.accountDemo : nil, isCurrent ? strings.accountCurrent : nil]

        return SettingsRowItem(
            id: "account-\(id.rawValue)",
            title: strings.accountName(record),
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
            message: strings.accountRemoveConfirm(strings.accountName(record)),
            actions: [
                PopupAlertAction(title: strings.accountRemoveAction, style: .destructive) {
                    switcher.removeAccount(record.id)
                },
                PopupAlertAction(title: strings.chatCancel, style: .cancel),
            ],
            theme: presentation.theme,
            in: view
        )
    }
}
