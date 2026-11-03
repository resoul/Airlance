import Haptics
import UIKit

final class StoryWidgetForm: UIView, UITextFieldDelegate {
    enum Suggestion: Equatable {
        case peer(StoryMentionPeer)
        case place(StoryPlace)

        var title: String {
            switch self {
            case .peer(let peer):
                peer.name
            case .place(let place):
                place.title
            }
        }
    }

    var onDone: (@MainActor (StoryWidget) -> Void)?
    var onCancel: (@MainActor () -> Void)?
    var onSearch: (@MainActor (String) -> Void)?

    let type: StoryWidgetType
    let strings: StoryStudioStrings
    let peers: [StoryMentionPeer]
    var fields: [UITextField] = []
    var suggestions: [Suggestion] = []
    var selected: Suggestion?
    private let dim = UIView()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let chips = UIScrollView()
    private var chipButtons: [UIButton] = []
    private var preview: StoryWidgetView?
    private var keyboardTop: CGFloat?

    init(type: StoryWidgetType, strings: StoryStudioStrings, peers: [StoryMentionPeer]) {
        self.type = type
        self.strings = strings
        self.peers = peers
        super.init(frame: .zero)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        addSubview(dim)
        setUpBar()
        chips.showsHorizontalScrollIndicator = false
        addSubview(chips)
        for placeholder in placeholders {
            addField(placeholder)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func begin() {
        alpha = 0
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
        fields.first?.becomeFirstResponder()
        if type == .mention || type == .location {
            textChanged()
        }
    }

    func dismiss() {
        endEditing(true)
        UIView.animate(withDuration: 0.2) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    func setSuggestions(_ suggestions: [Suggestion]) {
        self.suggestions = suggestions
        for button in chipButtons {
            button.removeFromSuperview()
        }
        chipButtons = suggestions.map { suggestion in
            let button = UIButton(type: .system)
            button.setTitle(suggestion.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.layer.cornerRadius = 16
            button.addAction(UIAction { [weak self] _ in
                self?.choose(suggestion)
            }, for: .touchUpInside)
            chips.addSubview(button)

            return button
        }
        styleChips()
        setNeedsLayout()
    }

    func refresh() {
        doneButton.isEnabled = widget(strict: true) != nil
        doneButton.alpha = doneButton.isEnabled ? 1 : 0.4
        guard let widget = widget(strict: false) else {
            preview?.removeFromSuperview()
            preview = nil

            return
        }

        if let preview {
            preview.update(widget)
        } else {
            let view = StoryWidgetView(widget: widget)
            view.isUserInteractionEnabled = false
            addSubview(view)
            preview = view
        }
        styleChips()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dim.frame = bounds
        let top = max(safeAreaInsets.top, 16) + 6
        cancelButton.frame = CGRect(x: 8, y: top, width: 110, height: 44)
        doneButton.frame = CGRect(x: bounds.width - 118, y: top, width: 110, height: 44)
        var y = cancelButton.frame.maxY + 12
        for field in fields {
            field.frame = CGRect(x: 20, y: y, width: bounds.width - 40, height: 46)
            y += 54
        }
        chips.frame = CGRect(x: 0, y: y, width: bounds.width, height: chipButtons.isEmpty ? 0 : 34)
        layoutChips()
        y = chips.frame.maxY + 18
        layoutPreview(top: y, bottom: (keyboardTop ?? bounds.height * 0.6) - 16)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let index = fields.firstIndex(of: textField) else {
            return true
        }

        if index + 1 < fields.count {
            fields[index + 1].becomeFirstResponder()
        } else {
            finish()
        }

        return false
    }

    private func setUpBar() {
        cancelButton.setTitle(strings.cancel, for: .normal)
        cancelButton.contentHorizontalAlignment = .left
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.tintColor = .white
        cancelButton.addAction(UIAction { [weak self] _ in
            self?.onCancel?()
        }, for: .touchUpInside)
        doneButton.setTitle(strings.done, for: .normal)
        doneButton.contentHorizontalAlignment = .right
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.tintColor = .white
        doneButton.addAction(UIAction { [weak self] _ in
            self?.finish()
        }, for: .touchUpInside)
        addSubview(cancelButton)
        addSubview(doneButton)
    }

    private func addField(_ placeholder: String) {
        let field = UITextField()
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.45)]
        )
        field.font = .systemFont(ofSize: 17, weight: .medium)
        field.textColor = .white
        field.tintColor = .white
        field.backgroundColor = UIColor(white: 1, alpha: 0.12)
        field.layer.cornerRadius = 14
        field.layer.cornerCurve = .continuous
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.returnKeyType = fields.count + 1 < placeholders.count ? .next : .done
        field.delegate = self
        configure(field, index: fields.count)
        field.addAction(UIAction { [weak self] _ in
            self?.textChanged()
        }, for: .editingChanged)
        addSubview(field)
        fields.append(field)
    }

    private func layoutChips() {
        var x: CGFloat = 20
        for button in chipButtons {
            let width = min(ceil(button.intrinsicContentSize.width) + 26, 220)
            button.frame = CGRect(x: x, y: 0, width: width, height: 34)
            x += width + 8
        }
        chips.contentSize = CGSize(width: x + 12, height: 34)
    }

    private func styleChips() {
        for (index, button) in chipButtons.enumerated() {
            let isOn = suggestions.indices.contains(index) && suggestions[index] == selected
            button.backgroundColor = isOn ? .white : UIColor(white: 1, alpha: 0.16)
            button.tintColor = isOn ? .black : .white
        }
    }

    private func layoutPreview(top: CGFloat, bottom: CGFloat) {
        guard let preview else {
            return
        }

        preview.transform = .identity
        preview.layout(width: bounds.width)
        let room = max(bottom - top, 40)
        let scale = min(1, room / max(preview.bounds.height, 1))
        preview.center = CGPoint(x: bounds.midX, y: top + min(room, preview.bounds.height * scale) / 2)
        preview.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    private func choose(_ suggestion: Suggestion) {
        Haptics.play(.selection)
        selected = suggestion
        fields.first?.text = suggestion.title
        refresh()
    }

    private func finish() {
        guard let widget = widget(strict: true) else {
            Haptics.play(.error)

            return
        }

        onDone?(widget)
    }

    @objc
    private func keyboardChanged(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        keyboardTop = convert(frame, from: nil).minY
        setNeedsLayout()
    }
}
