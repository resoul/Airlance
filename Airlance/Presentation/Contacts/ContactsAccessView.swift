import UIKit

final class ContactsAccessView: UIView {
    var onAllow: (@MainActor () -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let textLabel = UILabel()
    private let allowButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.image = UIImage(systemName: "person.crop.circle.badge.plus")
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        iconView.contentMode = .center
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 0
        allowButton.layer.cornerCurve = .continuous
        allowButton.addAction(
            UIAction { [weak self] _ in
                self?.onAllow?()
            },
            for: .touchUpInside
        )

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, textLabel, allowButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(28, after: textLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -8),
            allowButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        let colors = presentation.theme.colors
        let fonts = presentation.theme.fonts
        let strings = presentation.strings

        iconView.tintColor = colors.accent
        titleLabel.text = strings.contactsAccessTitle
        titleLabel.font = fonts.title
        titleLabel.textColor = colors.textPrimary
        textLabel.text = strings.contactsAccessText
        textLabel.font = fonts.body
        textLabel.textColor = colors.textSecondary
        allowButton.setTitle(strings.contactsAccessAllow, for: .normal)
        allowButton.setTitleColor(colors.onAccent, for: .normal)
        allowButton.titleLabel?.font = fonts.headline
        allowButton.backgroundColor = colors.accent
        allowButton.layer.cornerRadius = 26
    }
}
