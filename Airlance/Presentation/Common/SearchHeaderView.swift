import UIKit

final class SearchHeaderView: UIView {
    static let height: CGFloat = 56

    var onChange: (@MainActor (String) -> Void)?

    private let field = UISearchTextField()

    var query: String {
        (field.text ?? "").trimmingCharacters(in: .whitespaces)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        field.returnKeyType = .search
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.layer.cornerCurve = .continuous
        field.addAction(
            UIAction { [weak self] _ in
                self?.changed()
            },
            for: .editingChanged
        )
        field.addAction(
            UIAction { [weak self] _ in
                self?.field.resignFirstResponder()
            },
            for: .editingDidEndOnExit
        )
        addSubview(field)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        field.frame = bounds.insetBy(dx: 16, dy: 8)
        field.layer.cornerRadius = field.bounds.height / 2
    }

    func apply(_ presentation: PresentationData, placeholder: String) {
        let colors = presentation.theme.colors

        backgroundColor = colors.background
        field.backgroundColor = colors.surface
        field.textColor = colors.textPrimary
        field.tintColor = colors.accent
        field.font = presentation.theme.fonts.body
        field.leftView?.tintColor = colors.textSecondary
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: colors.textSecondary]
        )
    }

    private func changed() {
        onChange?(query)
    }
}
