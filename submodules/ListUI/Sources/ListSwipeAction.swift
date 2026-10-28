import UIKit

public struct ListSwipeAction: Sendable {
    public let title: String
    public let symbol: String
    public let color: UIColor
    public let handler: @MainActor @Sendable () -> Void

    public init(title: String, symbol: String, color: UIColor, handler: @escaping @MainActor @Sendable () -> Void) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.handler = handler
    }
}

public struct ListSwipeActions: Sendable {
    public let leading: [ListSwipeAction]
    public let trailing: [ListSwipeAction]

    public init(leading: [ListSwipeAction] = [], trailing: [ListSwipeAction] = []) {
        self.leading = leading
        self.trailing = trailing
    }
}

@MainActor
final class ListSwipeButtonsView: UIView {
    private let leading: [ListSwipeButton]
    private let trailing: [ListSwipeButton]

    init(actions: ListSwipeActions, onAction: @escaping @MainActor (ListSwipeAction) -> Void) {
        leading = actions.leading.map { action in
            Self.button(for: action, onAction: onAction)
        }
        trailing = actions.trailing.map { action in
            Self.button(for: action, onAction: onAction)
        }
        super.init(frame: .zero)
        clipsToBounds = true
        for button in leading + trailing {
            addSubview(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func layout(offset: CGFloat, isFull: Bool) {
        let reveal = abs(offset)
        for (index, button) in trailing.enumerated() {
            let share = reveal / CGFloat(trailing.count)
            let x = bounds.width - reveal + share * CGFloat(index)
            var frame = CGRect(x: x, y: 0, width: share + 1, height: bounds.height)
            if isFull, index == trailing.count - 1 {
                frame = CGRect(x: bounds.width - reveal, y: 0, width: reveal, height: bounds.height)
            }
            button.frame = frame
            button.isHidden = offset >= 0
        }
        for (index, button) in leading.enumerated() {
            let share = reveal / CGFloat(leading.count)
            var frame = CGRect(x: reveal - share * CGFloat(index + 1), y: 0, width: share + 1, height: bounds.height)
            if isFull, index == 0 {
                frame = CGRect(x: 0, y: 0, width: reveal, height: bounds.height)
            }
            button.frame = frame
            button.isHidden = offset <= 0
        }
    }

    private static func button(
        for action: ListSwipeAction,
        onAction: @escaping @MainActor (ListSwipeAction) -> Void
    ) -> ListSwipeButton {
        let button = ListSwipeButton(action: action)
        button.addAction(
            UIAction { _ in
                onAction(action)
            },
            for: .touchUpInside
        )

        return button
    }
}

@MainActor
final class ListSwipeButton: UIControl {
    private static let contentWidth: CGFloat = 76

    private let icon = UIImageView()
    private let label = UILabel()

    init(action: ListSwipeAction) {
        super.init(frame: .zero)
        backgroundColor = action.color
        clipsToBounds = true
        icon.tintColor = .white
        icon.contentMode = .center
        icon.image = UIImage(
            systemName: action.symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        )
        label.text = action.title
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        addSubview(icon)
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = Self.contentWidth
        let x = (bounds.width - width) / 2
        icon.frame = CGRect(x: x, y: bounds.midY - 22, width: width, height: 26)
        label.frame = CGRect(x: x - 4, y: bounds.midY + 6, width: width + 8, height: 16)
        let visible = min(1, bounds.width / 40)
        icon.alpha = visible
        label.alpha = visible
    }
}
