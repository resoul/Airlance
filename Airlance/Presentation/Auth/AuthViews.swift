import Theme
import UIKit

final class AuthFieldView: UIView {
    var onChange: (@MainActor () -> Void)?

    let textField = UITextField()

    private let kind: AuthFieldKind

    init(kind: AuthFieldKind) {
        self.kind = kind
        super.init(frame: .zero)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addAction(
            UIAction { [weak self] _ in
                self?.onChange?()
            },
            for: .editingChanged
        )
        configure()
        addSubview(textField)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var text: String {
        textField.text ?? ""
    }

    var isValid: Bool {
        kind.isValid(text)
    }

    func apply(_ presentation: PresentationData) {
        let theme = presentation.theme
        backgroundColor = theme.colors.surface
        textField.font = theme.fonts.body
        textField.textColor = theme.colors.textPrimary
        textField.tintColor = theme.colors.accent
        textField.attributedPlaceholder = NSAttributedString(
            string: kind.placeholder(presentation.strings),
            attributes: [.foregroundColor: theme.colors.textSecondary]
        )
    }

    private func configure() {
        switch kind {
        case .firstName:
            textField.textContentType = .givenName
            textField.autocapitalizationType = .words
        case .lastName:
            textField.textContentType = .familyName
            textField.autocapitalizationType = .words
        case .username:
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
    }
}

extension UIButton {
    func applyAuthFilled(title: String, theme: AppTheme, isBusy: Bool = false) {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = theme.colors.accent
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        configuration.attributedTitle = authTitle(title, font: theme.fonts.headline)
        configuration.showsActivityIndicator = isBusy
        configuration.imagePadding = 8
        self.configuration = configuration
    }

    func applyAuthPlain(title: String, theme: AppTheme) {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = theme.colors.accent
        configuration.attributedTitle = authTitle(title, font: theme.fonts.body)
        self.configuration = configuration
    }

    private func authTitle(_ title: String, font: UIFont) -> AttributedString {
        var text = AttributedString(title)
        text.font = font

        return text
    }
}
