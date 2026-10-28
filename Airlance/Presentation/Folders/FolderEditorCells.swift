import Haptics
import Theme
import UIKit

final class FolderNameCell: UITableViewCell, UITextFieldDelegate {
    let field = UITextField()

    var onNameChange: ((String) -> Void)?
    var onEmojiTap: (() -> Void)?

    private let emojiButton = UIButton(type: .system)

    init() {
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none
        emojiButton.titleLabel?.font = .systemFont(ofSize: 22)
        emojiButton.addAction(
            UIAction { [weak self] _ in
                self?.onEmojiTap?()
            },
            for: .touchUpInside
        )
        field.delegate = self
        field.returnKeyType = .done
        field.addAction(
            UIAction { [weak self] _ in
                self?.onNameChange?(self?.field.text ?? "")
            },
            for: .editingChanged
        )
        contentView.addSubview(emojiButton)
        contentView.addSubview(field)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme, placeholder: String) {
        backgroundColor = theme.colors.surface
        field.font = theme.fonts.body
        field.textColor = theme.colors.textPrimary
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: theme.colors.textSecondary]
        )
    }

    func setEmoji(_ emoji: String?, tint: UIColor) {
        if let emoji {
            emojiButton.setImage(nil, for: .normal)
            emojiButton.setTitle(emoji, for: .normal)
        } else {
            emojiButton.setTitle(nil, for: .normal)
            let configuration = UIImage.SymbolConfiguration(pointSize: 20)
            let image = UIImage(systemName: "face.smiling.inverse", withConfiguration: configuration)
            emojiButton.setImage(image, for: .normal)
        }
        emojiButton.tintColor = tint
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let current = textField.text ?? ""
        guard let range = Range(range, in: current) else {
            return false
        }

        return current.replacingCharacters(in: range, with: string).count <= 24
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = contentView.bounds
        emojiButton.frame = CGRect(x: bounds.width - 52, y: (bounds.height - 40) / 2, width: 40, height: 40)
        field.frame = CGRect(x: 20, y: 0, width: bounds.width - 76, height: bounds.height)
    }
}

final class FolderColorCell: UITableViewCell {
    var onSelect: ((Int?) -> Void)?

    private var buttons: [UIButton] = []
    private var selectedColor: Int?

    init() {
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none
        for index in FolderStyle.colorOrder {
            let button = UIButton(type: .custom)
            button.backgroundColor = FolderStyle.colors[index]
            button.tag = index
            button.addAction(
                UIAction { [weak self] _ in
                    self?.tapped(index)
                },
                for: .touchUpInside
            )
            contentView.addSubview(button)
            buttons.append(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ theme: AppTheme) {
        backgroundColor = theme.colors.surface
        for button in buttons {
            button.layer.borderColor = theme.colors.surface.cgColor
        }
    }

    func select(_ index: Int?) {
        selectedColor = index
        for button in buttons {
            let isSelected = button.tag == index
            button.layer.borderWidth = isSelected ? 3 : 0
            button.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size: CGFloat = 30
        let gap = (contentView.bounds.width - 32 - size * CGFloat(buttons.count)) / CGFloat(max(buttons.count - 1, 1))
        for (offset, button) in buttons.enumerated() {
            button.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            button.center = CGPoint(
                x: 16 + size / 2 + CGFloat(offset) * (size + gap),
                y: contentView.bounds.midY
            )
            button.layer.cornerRadius = size / 2
        }
    }

    private func tapped(_ index: Int) {
        let next = selectedColor == index ? nil : index
        Haptics.play(.selection)
        onSelect?(next)
    }
}

final class FolderIconView: UIView {
    private let symbol = UIImageView()
    private let emoji = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        symbol.image = UIImage(systemName: "folder.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 64))
        symbol.contentMode = .center
        emoji.font = .systemFont(ofSize: 64)
        emoji.textAlignment = .center
        addSubview(symbol)
        addSubview(emoji)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(emoji value: String?, tint: UIColor) {
        emoji.text = value
        emoji.isHidden = value == nil
        symbol.isHidden = value != nil
        symbol.tintColor = tint
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frame = CGRect(x: 0, y: 16, width: bounds.width, height: 80)
        symbol.frame = frame
        emoji.frame = frame
    }
}
