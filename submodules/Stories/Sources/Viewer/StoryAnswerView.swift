import UIKit

final class StoryAnswerView: UIView, UITextFieldDelegate {
    var onSend: (@MainActor (String) -> Void)?
    var onClose: (@MainActor () -> Void)?

    private let dim = UIView()
    private let card = UIView()
    private let prompt = UILabel()
    private let field = UITextField()
    private let sendButton = UIButton(type: .system)

    init(prompt text: String, hint: String, tint: UIColor, sendTitle: String) {
        super.init(frame: .zero)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dimTapped)))
        addSubview(dim)
        card.backgroundColor = .white
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        addSubview(card)
        prompt.text = text
        prompt.numberOfLines = 0
        prompt.textAlignment = .center
        prompt.font = StoryWidgetView.font(size: 20, weight: .heavy)
        prompt.textColor = .black
        card.addSubview(prompt)
        field.placeholder = hint
        field.font = .systemFont(ofSize: 17, weight: .medium)
        field.backgroundColor = UIColor(white: 0, alpha: 0.06)
        field.layer.cornerRadius = 14
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.returnKeyType = .send
        field.tintColor = tint
        field.delegate = self
        card.addSubview(field)
        sendButton.setTitle(sendTitle, for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendButton.backgroundColor = tint
        sendButton.tintColor = StoryLook.contrast(for: tint)
        sendButton.layer.cornerRadius = 22
        sendButton.addAction(UIAction { [weak self] _ in
            self?.send()
        }, for: .touchUpInside)
        card.addSubview(sendButton)
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
        field.becomeFirstResponder()
    }

    func dismiss() {
        endEditing(true)
        UIView.animate(withDuration: 0.2) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dim.frame = bounds
        let width = min(bounds.width - 40, 380)
        let inner = width - 40
        let promptHeight = ceil(prompt.sizeThatFits(CGSize(width: inner, height: .greatestFiniteMagnitude)).height)
        prompt.frame = CGRect(x: 20, y: 22, width: inner, height: promptHeight)
        field.frame = CGRect(x: 20, y: prompt.frame.maxY + 16, width: inner, height: 48)
        sendButton.frame = CGRect(x: 20, y: field.frame.maxY + 12, width: inner, height: 44)
        let height = sendButton.frame.maxY + 20
        card.frame = CGRect(
            x: (bounds.width - width) / 2,
            y: max(safeAreaInsets.top + 60, bounds.height * 0.22),
            width: width,
            height: height
        )
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send()

        return false
    }

    private func send() {
        let text = (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        onSend?(text)
    }

    @objc
    private func dimTapped() {
        onClose?()
    }
}
