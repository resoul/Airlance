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
                self?.changed()
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

    private func changed() {
        let clean = kind.sanitized(text)
        if clean != text {
            textField.text = clean
        }
        onChange?()
    }

    private func configure() {
        switch kind {
        case .email:
            textField.keyboardType = .emailAddress
            textField.textContentType = .emailAddress
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        case .code:
            textField.keyboardType = .numberPad
            textField.textContentType = .oneTimeCode
            textField.textAlignment = .center
        case .recovery:
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
        case .name:
            textField.textContentType = .name
            textField.autocapitalizationType = .words
        case .username:
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
    }
}

final class AuthCodesView: UIView {
    static let samples = [
        "7KQ2-M9XD", "P4TN-2HVC", "W8LR-6FJA", "3ZGB-Q7SE", "H5YK-9DNM",
        "C2VP-4XTL", "J6RF-8WQB", "M9EA-3KGZ", "T7SH-5CPY", "B4XD-2NVR",
    ]

    private var labels: [UILabel] = []

    init() {
        super.init(frame: .zero)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        let rows = stride(from: 0, to: Self.samples.count, by: 2).map { index in
            row(Array(Self.samples[index..<min(index + 2, Self.samples.count)]))
        }
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme) {
        backgroundColor = theme.colors.surface
        for label in labels {
            label.textColor = theme.colors.textPrimary
        }
    }

    private func row(_ codes: [String]) -> UIStackView {
        let views = codes.map { code in
            let label = UILabel()
            label.text = code
            label.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
            label.textAlignment = .center
            labels.append(label)

            return label
        }
        let row = UIStackView(arrangedSubviews: views)
        row.distribution = .fillEqually

        return row
    }
}

extension UIButton {
    func applyAuthFilled(title: String, theme: AppTheme) {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = theme.colors.accent
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        configuration.attributedTitle = authTitle(title, font: theme.fonts.headline)
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
