import Haptics
import UIKit

final class CameraTextView: UIView {
    var onClose: (@MainActor () -> Void)?

    private let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let textView = UITextView()
    private let copyButton = UIButton(type: .system)
    private let strings: CameraStrings
    private let text: String

    init(text: String, strings: CameraStrings) {
        self.text = text
        self.strings = strings
        super.init(frame: .zero)
        addSubview(backdrop)
        titleLabel.text = strings.scanText
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        let symbol = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbol), for: .normal)
        closeButton.tintColor = .white
        closeButton.accessibilityLabel = strings.close
        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 18)
        textView.textColor = text.isEmpty ? UIColor.white.withAlphaComponent(0.6) : .white
        textView.text = text.isEmpty ? strings.noText : text
        textView.textAlignment = text.isEmpty ? .center : .natural
        copyButton.setTitle(strings.copyAll, for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        copyButton.tintColor = .black
        copyButton.backgroundColor = .systemYellow
        copyButton.isHidden = text.isEmpty
        copyButton.addAction(UIAction { [weak self] _ in
            self?.copyAll()
        }, for: .touchUpInside)
        for view in [titleLabel, closeButton, textView, copyButton] {
            backdrop.contentView.addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backdrop.frame = bounds
        let safe = safeAreaInsets
        let top = max(safe.top, 16) + 6
        closeButton.frame = CGRect(x: 12, y: top, width: 44, height: 44)
        titleLabel.frame = CGRect(x: 64, y: top, width: bounds.width - 128, height: 44)
        let bottom = bounds.height - max(safe.bottom, 16) - 8
        copyButton.frame = CGRect(x: 24, y: bottom - 50, width: bounds.width - 48, height: 50)
        copyButton.layer.cornerRadius = 25
        textView.frame = CGRect(x: 16, y: top + 56, width: bounds.width - 32, height: copyButton.frame.minY - top - 72)
    }

    func show() {
        alpha = 0
        UIView.animate(withDuration: 0.25) {
            self.alpha = 1
        }
    }

    func hide() {
        UIView.animate(withDuration: 0.2) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    private func copyAll() {
        UIPasteboard.general.string = text
        Haptics.play(.success)
        copyButton.setTitle(strings.copied, for: .normal)
    }
}
