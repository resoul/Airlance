import UIKit

extension StoryWidgetView {
    func rebuildRows() {
        for row in rows {
            row.removeFromSuperview()
        }
        switch widget.kind {
        case .poll(let poll):
            rows = poll.options.map { option in
                StoryWidgetRow(kind: .option(option))
            }
        case .question(_, let hint):
            rows = [StoryWidgetRow(kind: .field(hint))]
        case .addYours:
            rows = [StoryWidgetRow(kind: .button("camera.fill"))]
        case .mention, .location, .link, .reaction:
            rows = []
        }
        for row in rows {
            addSubview(row)
        }
    }

    func layoutCard(heading: String?, text: String, palette: Palette) {
        let width = 72 * unit
        let padding = 4.5 * unit
        let inner = width - padding * 2
        var top = padding
        icon.isHidden = true
        caption.isHidden = heading == nil
        if let heading {
            caption.font = Self.font(size: 3.6 * unit, weight: .heavy)
            caption.textColor = widget.style == .light ? palette.accent : palette.secondary
            caption.text = heading
            let height = ceil(caption.sizeThatFits(CGSize(width: inner, height: .greatestFiniteMagnitude)).height)
            caption.frame = CGRect(x: padding, y: top, width: inner, height: height)
            top += height + 1.5 * unit
        }
        title.numberOfLines = 0
        title.lineBreakMode = .byWordWrapping
        title.font = Self.font(size: 5.4 * unit, weight: .heavy)
        title.textColor = palette.primary
        title.text = text
        let height = ceil(title.sizeThatFits(CGSize(width: inner, height: .greatestFiniteMagnitude)).height)
        title.frame = CGRect(x: padding, y: top, width: inner, height: height)
        top += height + 3 * unit
        for row in rows {
            let rowHeight = 11 * unit
            row.frame = CGRect(x: padding, y: top, width: inner, height: rowHeight)
            row.layout(unit: unit)
            top += rowHeight + 2 * unit
        }
        bounds = CGRect(x: 0, y: 0, width: width, height: top - (rows.isEmpty ? 3 * unit : 2 * unit) + padding)
        layer.cornerRadius = 6 * unit
    }
}

final class StoryWidgetRow: UIView {
    enum Kind {
        case option(String)
        case field(String)
        case button(String)
    }

    let kind: Kind
    private let label = UILabel()
    private let mark = UIImageView()

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        layer.cornerCurve = .continuous
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        mark.contentMode = .scaleAspectFit
        addSubview(label)
        addSubview(mark)
        switch kind {
        case .option(let text):
            label.text = text
        case .field(let hint):
            label.text = hint
        case .button:
            break
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func layout(unit: CGFloat) {
        layer.cornerRadius = bounds.height / 2
        let side = 4.6 * unit
        label.font = StoryWidgetView.font(size: 4.4 * unit, weight: .bold)
        label.frame = bounds.insetBy(dx: side + 3 * unit, dy: 0)
        let configuration = UIImage.SymbolConfiguration(pointSize: side, weight: .bold)
        switch kind {
        case .button(let symbol):
            mark.image = UIImage(systemName: symbol, withConfiguration: configuration)
            mark.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        case .option, .field:
            mark.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)
            mark.frame = CGRect(
                x: bounds.width - side - 2.6 * unit,
                y: (bounds.height - side) / 2,
                width: side,
                height: side
            )
        }
    }

    func apply(palette: StoryWidgetView.Palette, chosen: Bool?) {
        switch kind {
        case .option:
            let isChosen = chosen == true
            backgroundColor = isChosen ? palette.accent : palette.field
            label.textColor = isChosen ? StoryLook.contrast(for: palette.accent) : palette.primary
            mark.tintColor = label.textColor
            mark.isHidden = !isChosen
            alpha = chosen == false ? 0.55 : 1
        case .field:
            backgroundColor = palette.field
            label.textColor = palette.secondary
            mark.isHidden = true
        case .button:
            backgroundColor = palette.accent
            mark.tintColor = StoryLook.contrast(for: palette.accent)
            mark.isHidden = false
        }
    }
}
