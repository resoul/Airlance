@preconcurrency import AsyncDisplayKit
import AvatarUI
import Theme
import UIKit

final class ProfileEditAvatarView: UIView {
    static let height: CGFloat = 158

    var onTap: (@MainActor () -> Void)?

    private let avatar = AvatarNode()
    private let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(avatar.view)
        avatar.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ descriptor: AvatarDescriptor, title: String, theme: AppTheme) {
        avatar.apply(descriptor, presentation: .profile)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = theme.fonts.body
        button.tintColor = theme.colors.accent
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 104
        avatar.frame = CGRect(x: (bounds.width - side) / 2, y: 6, width: side, height: side)
        button.frame = CGRect(x: 16, y: avatar.frame.maxY + 6, width: bounds.width - 32, height: 36)
    }

    @objc
    private func tapped() {
        onTap?()
    }
}

final class ProfileEditNameCard: UIView, UITextFieldDelegate {
    static let height: CGFloat = 104

    var onChange: (@MainActor (_ first: String, _ last: String) -> Void)?

    private let firstField = UITextField()
    private let lastField = UITextField()
    private let separator = UIView()

    init(first: String, last: String, strings: AppStrings, theme: AppTheme) {
        super.init(frame: .zero)
        backgroundColor = theme.colors.surface
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        separator.backgroundColor = theme.colors.separator
        addSubview(separator)
        firstField.text = first
        firstField.placeholder = strings.profileEditFirstName
        firstField.returnKeyType = .next
        lastField.text = last
        lastField.placeholder = strings.profileEditLastName
        lastField.returnKeyType = .done
        for field in [firstField, lastField] {
            field.font = theme.fonts.body
            field.textColor = theme.colors.textPrimary
            field.tintColor = theme.colors.accent
            field.autocorrectionType = .no
            field.delegate = self
            field.addAction(
                UIAction { [weak self] _ in
                    self?.changed()
                },
                for: .editingChanged
            )
            addSubview(field)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rowHeight = bounds.height / 2
        firstField.frame = CGRect(x: 18, y: 0, width: bounds.width - 36, height: rowHeight)
        lastField.frame = CGRect(x: 18, y: rowHeight, width: bounds.width - 36, height: rowHeight)
        separator.frame = CGRect(x: 18, y: rowHeight, width: bounds.width - 18, height: 0.5)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === firstField {
            lastField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }

        return false
    }

    private func changed() {
        onChange?(firstField.text ?? "", lastField.text ?? "")
    }
}

final class ProfileEditBioCard: UIView, UITextViewDelegate {
    static let height: CGFloat = 92

    var onChange: (@MainActor (String) -> Void)?

    private let textView = UITextView()
    private let placeholder = UILabel()

    init(text: String, strings: AppStrings, theme: AppTheme) {
        super.init(frame: .zero)
        backgroundColor = theme.colors.surface
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        textView.backgroundColor = .clear
        textView.text = text
        textView.font = theme.fonts.body
        textView.textColor = theme.colors.textPrimary
        textView.tintColor = theme.colors.accent
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 13, bottom: 12, right: 13)
        textView.delegate = self
        addSubview(textView)
        placeholder.text = strings.profileEditBio
        placeholder.font = theme.fonts.body
        placeholder.textColor = theme.colors.textSecondary
        placeholder.isHidden = !text.isEmpty
        placeholder.isUserInteractionEnabled = false
        addSubview(placeholder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        placeholder.frame = CGRect(x: 18, y: 14, width: bounds.width - 36, height: ceil(placeholder.font.lineHeight))
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString? ?? ""

        return current.replacingCharacters(in: range, with: text).count <= MyProfile.bioLimit
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
        onChange?(textView.text)
    }
}
