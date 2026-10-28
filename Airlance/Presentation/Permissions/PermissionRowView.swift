import PermissionsAPI
import UIKit

final class PermissionRowView: UIView {
    private let permission: Permission
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let statusLabel = UILabel()
    private let actionButton: UIButton

    init(permission: Permission, onAction: @escaping @MainActor (Permission) -> Void) {
        self.permission = permission
        actionButton = UIButton.action {
            onAction(permission)
        }
        super.init(frame: .zero)
        setUpViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func render(status: PermissionStatus?, data: PresentationData) {
        let colors = data.theme.colors
        let fonts = data.theme.fonts
        let strings = data.strings

        titleLabel.text = strings.title(for: permission)
        titleLabel.font = fonts.headline
        titleLabel.textColor = colors.textPrimary
        summaryLabel.text = strings.summary(for: permission)
        summaryLabel.font = fonts.subheadline
        summaryLabel.textColor = colors.textSecondary
        statusLabel.text = status.map(strings.title(for:))
        statusLabel.font = fonts.subheadline
        statusLabel.textColor = status?.allowsUse == true ? colors.accent : colors.textSecondary

        switch status {
        case .notDetermined:
            actionButton.isHidden = false
            actionButton.apply(title: strings.permissionsAllow, theme: data.theme)
        case .denied, .limited:
            actionButton.isHidden = false
            actionButton.apply(title: strings.permissionsOpenSettings, theme: data.theme)
        case .granted, .restricted, nil:
            actionButton.isHidden = true
        }
    }

    private func setUpViews() {
        summaryLabel.numberOfLines = 0
        titleLabel.numberOfLines = 0
        actionButton.contentHorizontalAlignment = .leading

        let header = UIStackView(arrangedSubviews: [titleLabel, statusLabel])
        header.spacing = 8
        header.alignment = .firstBaseline
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [header, summaryLabel, actionButton])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}
