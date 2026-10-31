import UIKit

final class ChatSearchBar: UIView {
    static let height: CGFloat = 46

    var onOlder: (@MainActor () -> Void)?
    var onNewer: (@MainActor () -> Void)?

    private let label = UILabel()
    private let older = ChatSearchBar.button("chevron.up")
    private let newer = ChatSearchBar.button("chevron.down")

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = Self.height / 2
        layer.cornerCurve = .continuous
        addSubview(label)
        addSubview(older)
        addSubview(newer)
        older.addAction(
            UIAction { [weak self] _ in
                self?.onOlder?()
            },
            for: .touchUpInside
        )
        newer.addAction(
            UIAction { [weak self] _ in
                self?.onNewer?()
            },
            for: .touchUpInside
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func apply(_ presentation: PresentationData) {
        let colors = presentation.theme.colors
        backgroundColor = colors.surface
        label.font = presentation.theme.fonts.body
        label.textColor = colors.textPrimary
        older.tintColor = colors.accent
        newer.tintColor = colors.accent
    }

    func update(_ search: HistorySearch?, strings: AppStrings) {
        guard let search, !search.query.trimmingCharacters(in: .whitespaces).isEmpty else {
            label.text = nil
            older.isEnabled = false
            newer.isEnabled = false

            return
        }

        label.text = search.matches.isEmpty
            ? strings.chatSearchEmpty
            : strings.chatSearchPosition(String(search.matches.count - search.current), String(search.matches.count))
        older.isEnabled = search.current > 0
        newer.isEnabled = search.current < search.matches.count - 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 48
        newer.frame = CGRect(x: bounds.width - 6 - side, y: 0, width: side, height: bounds.height)
        older.frame = CGRect(x: newer.frame.minX - side, y: 0, width: side, height: bounds.height)
        label.frame = CGRect(x: 20, y: 0, width: older.frame.minX - 24, height: bounds.height)
    }

    private static func button(_ symbol: String) -> UIButton {
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)

        return button
    }
}
