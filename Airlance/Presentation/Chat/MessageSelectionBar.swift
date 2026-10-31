import UIKit

final class MessageSelectionBar: UIView {
    static let height: CGFloat = 46

    var onDelete: (@MainActor () -> Void)?
    var onCopy: (@MainActor () -> Void)?
    var onForward: (@MainActor () -> Void)?

    private let delete = MessageSelectionBar.button("trash")
    private let copy = MessageSelectionBar.button("doc.on.doc")
    private let forward = MessageSelectionBar.button("arrowshape.turn.up.right")

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = Self.height / 2
        layer.cornerCurve = .continuous
        let actions = [
            (delete, #selector(deleteTapped)),
            (copy, #selector(copyTapped)),
            (forward, #selector(forwardTapped)),
        ]
        for (button, action) in actions {
            button.addTarget(self, action: action, for: .touchUpInside)
            addSubview(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        let colors = presentation.theme.colors
        let strings = presentation.strings
        backgroundColor = colors.surface
        delete.tintColor = colors.destructive
        copy.tintColor = colors.accent
        forward.tintColor = colors.accent
        delete.accessibilityLabel = strings.chatDelete
        copy.accessibilityLabel = strings.chatCopy
        forward.accessibilityLabel = strings.chatForward
    }

    func update(count: Int, canDelete: Bool, canCopy: Bool) {
        delete.isEnabled = count > 0 && canDelete
        copy.isEnabled = count > 0 && canCopy
        forward.isEnabled = count > 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 56
        delete.frame = CGRect(x: 8, y: 0, width: side, height: bounds.height)
        copy.frame = CGRect(x: (bounds.width - side) / 2, y: 0, width: side, height: bounds.height)
        forward.frame = CGRect(x: bounds.width - 8 - side, y: 0, width: side, height: bounds.height)
    }

    @objc
    private func deleteTapped() {
        onDelete?()
    }

    @objc
    private func copyTapped() {
        onCopy?()
    }

    @objc
    private func forwardTapped() {
        onForward?()
    }

    private static func button(_ symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)

        return button
    }
}
