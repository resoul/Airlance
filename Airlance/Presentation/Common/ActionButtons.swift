import Theme
import UIKit

extension UIViewController {
    func placeActionButtons(_ buttons: [UIButton]) {
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }
}

extension UIButton {
    static func action(_ handler: @escaping @MainActor () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.addAction(
            UIAction { _ in
                handler()
            },
            for: .touchUpInside
        )

        return button
    }

    func apply(title: String, theme: AppTheme) {
        setTitle(title, for: .normal)
        setTitleColor(theme.colors.accent, for: .normal)
        titleLabel?.font = theme.fonts.headline
    }
}
