import UIKit

final class AvatarHoleView: UIView {
    private let shape = CAShapeLayer()

    var hole = CGRect.zero {
        didSet {
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        shape.fillRule = .evenOdd
        shape.fillColor = UIColor(white: 0, alpha: 0.65).cgColor
        layer.addSublayer(shape)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(ovalIn: hole))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.frame = bounds
        shape.path = path.cgPath
        CATransaction.commit()
    }
}

final class AvatarEditorChrome: UIView {
    private static let buttonSide: CGFloat = 52

    var onCancel: (@MainActor () -> Void)?
    var onDone: (@MainActor () -> Void)?

    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let hintLabel = UILabel()

    init(hint: String, presentation: PresentationData) {
        super.init(frame: .zero)
        let colors = presentation.theme.colors
        let symbol = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        cancelButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbol), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor(white: 1, alpha: 0.16)
        cancelButton.accessibilityLabel = presentation.strings.chatCancel
        doneButton.setImage(UIImage(systemName: "checkmark", withConfiguration: symbol), for: .normal)
        doneButton.tintColor = colors.onAccent
        doneButton.backgroundColor = colors.accent
        doneButton.accessibilityLabel = presentation.strings.authProfileDone
        for button in [cancelButton, doneButton] {
            button.layer.cornerRadius = Self.buttonSide / 2
            addSubview(button)
        }
        cancelButton.addAction(
            UIAction { [weak self] _ in
                self?.onCancel?()
            },
            for: .touchUpInside
        )
        doneButton.addAction(
            UIAction { [weak self] _ in
                self?.onDone?()
            },
            for: .touchUpInside
        )
        spinner.color = colors.onAccent
        spinner.hidesWhenStopped = true
        doneButton.addSubview(spinner)
        hintLabel.text = hint
        hintLabel.font = presentation.theme.fonts.subheadline
        hintLabel.textColor = UIColor(white: 1, alpha: 0.8)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2
        addSubview(hintLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setHint(_ text: String) {
        hintLabel.text = text
    }

    func setBusy(_ isBusy: Bool) {
        isUserInteractionEnabled = !isBusy
        doneButton.imageView?.alpha = isBusy ? 0 : 1
        if isBusy {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = Self.buttonSide
        let top = bounds.height - side
        cancelButton.frame = CGRect(x: 0, y: top, width: side, height: side)
        doneButton.frame = CGRect(x: bounds.width - side, y: top, width: side, height: side)
        spinner.center = CGPoint(x: side / 2, y: side / 2)
        hintLabel.frame = CGRect(x: side + 12, y: top, width: bounds.width - 2 * side - 24, height: side)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)

        return hit === self ? nil : hit
    }
}
