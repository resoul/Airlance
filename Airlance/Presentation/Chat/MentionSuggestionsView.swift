import ChatHistory
import Haptics
import UIKit

final class MentionSuggestionsView: UIView {
    static let rowHeight: CGFloat = 46
    static let maxRows = 4

    var onPick: (@MainActor (MessageCommenter) -> Void)?

    private let scroll = UIScrollView()
    private let separator = UIView()
    private var people: [MessageCommenter] = []
    private var rows: [UIControl] = []
    private var presentation: PresentationData?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        scroll.showsVerticalScrollIndicator = false
        addSubview(scroll)
        addSubview(separator)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var contentHeight: CGFloat {
        Self.rowHeight * CGFloat(min(people.count, Self.maxRows))
    }

    func apply(_ presentation: PresentationData) {
        self.presentation = presentation
        backgroundColor = presentation.theme.colors.background
        separator.backgroundColor = presentation.theme.colors.separator
        setPeople(people)
    }

    func setPeople(_ people: [MessageCommenter]) {
        self.people = people
        rows.forEach { row in
            row.removeFromSuperview()
        }
        guard let presentation else {
            rows = []

            return
        }

        rows = people.map { person in
            row(for: person, presentation: presentation)
        }
        rows.forEach { row in
            scroll.addSubview(row)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scroll.frame = bounds
        separator.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
        for (index, row) in rows.enumerated() {
            row.frame = CGRect(x: 0, y: CGFloat(index) * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
        }
        scroll.contentSize = CGSize(width: bounds.width, height: Self.rowHeight * CGFloat(rows.count))
    }

    private func row(for person: MessageCommenter, presentation: PresentationData) -> UIControl {
        let row = UIControl()
        let side: CGFloat = 32
        let avatar = UIImageView(image: MessageReceiptsRow.avatar(person, side: side))
        avatar.frame = CGRect(x: 14, y: (Self.rowHeight - side) / 2, width: side, height: side)
        avatar.layer.cornerRadius = side / 2
        avatar.clipsToBounds = true
        let name = UILabel()
        name.text = person.name
        name.font = presentation.theme.fonts.body
        name.textColor = presentation.theme.colors.textPrimary
        name.frame = CGRect(x: avatar.frame.maxX + 12, y: 0, width: 240, height: Self.rowHeight)
        for view in [avatar, name] {
            view.isUserInteractionEnabled = false
            row.addSubview(view)
        }
        row.accessibilityLabel = person.name
        row.addAction(
            UIAction { [weak self] _ in
                Haptics.play(.selection)
                self?.onPick?(person)
            },
            for: .touchUpInside
        )

        return row
    }
}
