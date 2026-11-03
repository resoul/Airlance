import UIKit

final class StoryWidgetView: UIView {
    struct Palette {
        let background: UIColor
        let primary: UIColor
        let secondary: UIColor
        let accent: UIColor
        let field: UIColor
    }

    private(set) var widget: StoryWidget
    var vote: Int? {
        didSet {
            applyVote()
        }
    }

    let icon = UIImageView()
    let title = UILabel()
    let caption = UILabel()
    var rows: [StoryWidgetRow] = []
    var unit: CGFloat = 1

    init(widget: StoryWidget) {
        self.widget = widget
        super.init(frame: .zero)
        layer.cornerCurve = .continuous
        icon.contentMode = .scaleAspectFit
        title.textAlignment = .center
        title.numberOfLines = 0
        caption.textAlignment = .center
        for view in [icon, title, caption] {
            addSubview(view)
        }
        rebuildRows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var palette: Palette {
        let tint = widget.tint.uiColor
        switch widget.style {
        case .light:
            return Palette(
                background: .white,
                primary: .black,
                secondary: UIColor(white: 0.45, alpha: 1),
                accent: tint,
                field: UIColor(white: 0, alpha: 0.06)
            )
        case .color:
            let contrast = StoryLook.contrast(for: tint)

            return Palette(
                background: tint,
                primary: contrast,
                secondary: contrast.withAlphaComponent(0.7),
                accent: contrast,
                field: contrast.withAlphaComponent(0.18)
            )
        case .dark:
            return Palette(
                background: UIColor(white: 0, alpha: 0.62),
                primary: .white,
                secondary: UIColor(white: 1, alpha: 0.6),
                accent: tint,
                field: UIColor(white: 1, alpha: 0.16)
            )
        }
    }

    func update(_ widget: StoryWidget) {
        let rebuilds = widget.kind != self.widget.kind
        self.widget = widget
        if rebuilds {
            rebuildRows()
        }
    }

    func layout(width: CGFloat) {
        unit = max(width, 1) / 100
        let palette = palette
        backgroundColor = palette.background
        switch widget.kind {
        case .mention(let peer):
            layoutPill(symbol: "at", text: peer.name, palette: palette)
        case .location(let place):
            layoutPill(symbol: "mappin.circle.fill", text: place.title.uppercased(), palette: palette)
        case .link(let url, let title):
            layoutPill(symbol: "link", text: title ?? url.host ?? url.absoluteString, palette: palette)
        case .reaction(let emoji):
            layoutReaction(emoji)
        case .poll(let poll):
            layoutCard(heading: nil, text: poll.question, palette: palette)
        case .question(let prompt, _):
            layoutCard(heading: nil, text: prompt, palette: palette)
        case .addYours(let prompt, let heading):
            layoutCard(heading: heading.uppercased(), text: prompt, palette: palette)
        }
        applyVote()
    }

    func option(at point: CGPoint) -> Int? {
        guard case .poll = widget.kind else {
            return nil
        }

        return rows.firstIndex { row in
            row.frame.insetBy(dx: 0, dy: -unit).contains(point)
        }
    }

    func pop() {
        UIView.animate(withDuration: 0.12) {
            self.icon.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            self.title.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.45,
                initialSpringVelocity: 0
            ) {
                self.icon.transform = .identity
                self.title.transform = .identity
            }
        }
    }

    private func layoutPill(symbol: String, text: String, palette: Palette) {
        let height = 12 * unit
        let side = 5.6 * unit
        let configuration = UIImage.SymbolConfiguration(pointSize: side, weight: .heavy)
        let color = widget.style == .light ? palette.accent : palette.primary
        icon.isHidden = false
        icon.image = UIImage(systemName: symbol, withConfiguration: configuration)
        icon.tintColor = color
        caption.isHidden = true
        title.numberOfLines = 1
        title.lineBreakMode = .byTruncatingTail
        title.font = Self.font(size: 5.4 * unit, weight: .heavy)
        title.textColor = color
        title.text = text
        let textWidth = min(ceil(title.intrinsicContentSize.width), 72 * unit)
        let width = 4 * unit + side + 1.6 * unit + textWidth + 4.4 * unit
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
        icon.frame = CGRect(x: 4 * unit, y: (height - side) / 2, width: side, height: side)
        title.frame = CGRect(x: icon.frame.maxX + 1.6 * unit, y: 0, width: textWidth, height: height)
        layer.cornerRadius = height * 0.3
    }

    private func layoutReaction(_ emoji: String) {
        let side = 24 * unit
        bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.cornerRadius = side / 2
        icon.isHidden = true
        caption.isHidden = true
        title.numberOfLines = 1
        title.font = .systemFont(ofSize: 13.5 * unit)
        title.text = emoji
        title.frame = bounds
    }

    private func applyVote() {
        let palette = palette
        for (index, row) in rows.enumerated() {
            row.apply(palette: palette, chosen: vote.map { vote in
                vote == index
            })
        }
    }

    static func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: max(size, 1), weight: weight)

        return base.fontDescriptor.withDesign(.rounded).map { descriptor in
            UIFont(descriptor: descriptor, size: max(size, 1))
        } ?? base
    }
}
