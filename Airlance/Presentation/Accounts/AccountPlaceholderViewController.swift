import Observers
import UIKit

struct AccountPlaceholderDependencies {
    let presentationContext: PresentationContext
    let accounts: any AccountSwitching
}

extension AppStrings {
    func accountName(_ record: AccountRecord) -> String {
        record.name.isEmpty ? accountDemoName(record.fixtureVariant + 1) : record.name
    }
}

final class AccountPlaceholderViewController: ScreenViewController {
    private let failedAccountID: AccountID?
    private let dependencies: AccountPlaceholderDependencies
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let addButton = UIButton(type: .system)
    private let otherButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private var observation: ObservationToken?

    init(failedAccountID: AccountID?, dependencies: AccountPlaceholderDependencies) {
        self.failedAccountID = failedAccountID
        self.dependencies = dependencies
        super.init(presentationSource: dependencies.presentationContext)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for label in [titleLabel, messageLabel] {
            label.numberOfLines = 0
            label.textAlignment = .center
        }
        addButton.addAction(
            UIAction { [weak self] _ in
                self?.dependencies.accounts.addDemoAccount()
            },
            for: .touchUpInside
        )
        otherButton.addAction(
            UIAction { [weak self] _ in
                self?.openOther()
            },
            for: .touchUpInside
        )
        retryButton.addAction(
            UIAction { [weak self] _ in
                self?.retry()
            },
            for: .touchUpInside
        )
        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, retryButton, otherButton, addButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(28, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        observation = dependencies.accounts.observeAccounts { [weak self] in
            guard let self else {
                return
            }

            self.apply(self.presentation)
        }
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -16),
        ])
    }

    override func apply(_ presentation: PresentationData) {
        super.apply(presentation)
        let theme = presentation.theme
        let strings = presentation.strings
        view.backgroundColor = theme.colors.background
        titleLabel.font = theme.fonts.title
        titleLabel.textColor = theme.colors.textPrimary
        messageLabel.font = theme.fonts.body
        messageLabel.textColor = theme.colors.textSecondary
        let failed = failedRecord
        titleLabel.text = failed.map(strings.accountName).map(strings.accountFailedTitle) ?? strings.accountEmptyTitle
        messageLabel.text = failed == nil ? strings.accountEmptyMessage : strings.accountFailedMessage
        retryButton.setTitle(strings.accountRetry, for: .normal)
        retryButton.titleLabel?.font = theme.fonts.headline
        retryButton.tintColor = theme.colors.accent
        retryButton.isHidden = failed == nil
        addButton.setTitle(strings.accountAdd, for: .normal)
        addButton.titleLabel?.font = failed == nil ? theme.fonts.headline : theme.fonts.body
        addButton.tintColor = theme.colors.accent
        otherButton.setTitle(strings.accountOther, for: .normal)
        otherButton.titleLabel?.font = theme.fonts.body
        otherButton.tintColor = theme.colors.accent
        otherButton.isHidden = otherAccount == nil
    }

    private var failedRecord: AccountRecord? {
        dependencies.accounts.accountRecords.first { record in
            record.id == failedAccountID
        }
    }

    private func retry() {
        if let failedAccountID {
            dependencies.accounts.retryAccount(failedAccountID)
        }
    }

    private var otherAccount: AccountID? {
        dependencies.accounts.accountRecords.first { record in
            record.id != failedAccountID
        }?.id
    }

    private func openOther() {
        if let otherAccount {
            dependencies.accounts.switchAccount(to: otherAccount)
        }
    }
}
