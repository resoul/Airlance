import Haptics
import Theme
import UIKit

@MainActor
public final class ReactionBarView: UIView {
    public static let height: CGFloat = 48

    private enum Hit: Equatable {
        case emoji(Int)
        case more
    }

    private static let slot: CGFloat = 40
    private static let columns = 8
    private static let inset: CGFloat = 4
    private static let hoverDelay: TimeInterval = 0.45

    public var onPick: (@MainActor (String) -> Void)?
    public var onExpand: (@MainActor (Bool) -> Void)?

    private let emojis: [String]
    private let quickCount: Int
    private var labels: [UILabel] = []
    private let chosenMark = UIView()
    private let moreButton = UIView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
    private var highlighted: Hit?
    private var isExpanded = false
    private var hoverTask: Task<Void, Never>?
    private var collapsedTop: CGFloat = 0

    public init(quick: [String], more: [String], chosen: String?, theme: AppTheme) {
        emojis = quick + more
        quickCount = quick.count
        super.init(frame: CGRect(
            x: 0,
            y: 0,
            width: CGFloat(Self.columns) * Self.slot + Self.inset * 2,
            height: Self.height
        ))
        let colors = theme.colors
        backgroundColor = colors.surface
        layer.cornerRadius = Self.height / 2
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)
        chosenMark.backgroundColor = colors.accent.withAlphaComponent(0.2)
        chosenMark.layer.cornerRadius = 17
        chosenMark.isHidden = true
        addSubview(chosenMark)
        addLabels(chosen: chosen)
        addMoreButton(color: colors.textSecondary)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func track(_ point: CGPoint) -> Bool {
        let hit = hit(at: point)
        guard hit != highlighted else {
            return hit != nil
        }

        highlighted = hit
        hoverTask?.cancel()
        if hit != nil {
            Haptics.play(.selection)
        }
        if hit == .more {
            hoverTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.hoverDelay * 1_000_000_000))
                guard !Task.isCancelled, let self, self.highlighted == .more else {
                    return
                }

                self.setExpanded(!self.isExpanded)
            }
        }
        animateHighlight()

        return hit != nil
    }

    public func release() -> String? {
        let hit = highlighted
        hoverTask?.cancel()
        highlighted = nil
        animateHighlight()
        switch hit {
        case .emoji(let index):
            return emojis[index]
        case .more:
            setExpanded(!isExpanded)

            return nil
        case nil:
            return nil
        }
    }

    private func addLabels(chosen: String?) {
        for (index, emoji) in emojis.enumerated() {
            let label = UILabel(frame: frame(at: index))
            label.text = emoji
            label.font = .systemFont(ofSize: 26)
            label.textAlignment = .center
            label.isAccessibilityElement = true
            label.accessibilityTraits = .button
            label.alpha = index < quickCount ? 1 : 0
            addSubview(label)
            labels.append(label)
            if emoji == chosen {
                chosenMark.frame = label.frame.insetBy(dx: 3, dy: 3)
                chosenMark.isHidden = false
                chosenMark.alpha = label.alpha
            }
        }
    }

    private func addMoreButton(color: UIColor) {
        let frame = frame(column: quickCount, row: 0)
        moreButton.frame = CGRect(x: frame.midX - 15, y: frame.midY - 15, width: 30, height: 30)
        moreButton.layer.cornerRadius = 15
        moreButton.backgroundColor = color.withAlphaComponent(0.15)
        moreButton.isUserInteractionEnabled = false
        moreButton.isAccessibilityElement = true
        moreButton.accessibilityTraits = .button
        chevron.tintColor = color
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        chevron.sizeToFit()
        chevron.center = CGPoint(x: 15, y: 15)
        moreButton.addSubview(chevron)
        addSubview(moreButton)
    }

    private func frame(at index: Int) -> CGRect {
        guard index >= quickCount else {
            return frame(column: index, row: 0)
        }

        let offset = index - quickCount

        return frame(column: offset % Self.columns, row: 1 + offset / Self.columns)
    }

    private func frame(column: Int, row: Int) -> CGRect {
        let top = row == 0 ? (Self.height - Self.slot) / 2 : Self.height - 2 + CGFloat(row - 1) * Self.slot

        return CGRect(x: Self.inset + CGFloat(column) * Self.slot, y: top, width: Self.slot, height: Self.slot)
    }

    private var expandedHeight: CGFloat {
        let rows = (emojis.count - quickCount + Self.columns - 1) / Self.columns

        return Self.height + CGFloat(rows) * Self.slot + 6
    }

    private func hit(at point: CGPoint) -> Hit? {
        let reach = isExpanded ? bounds : bounds.insetBy(dx: 0, dy: -24)
        guard reach.contains(point) else {
            return nil
        }

        let column = min(Self.columns - 1, max(0, Int((point.x - Self.inset) / Self.slot)))
        guard point.y >= Self.height - 2, isExpanded else {
            return column == quickCount ? .more : column < quickCount ? .emoji(column) : nil
        }

        let row = Int((point.y - Self.height + 2) / Self.slot)
        let index = quickCount + row * Self.columns + column

        return emojis.indices.contains(index) ? .emoji(index) : nil
    }

    private func animateHighlight() {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
            for (index, label) in self.labels.enumerated() {
                label.transform = self.highlighted == .emoji(index)
                    ? CGAffineTransform(translationX: 0, y: -8).scaledBy(x: 1.4, y: 1.4)
                    : .identity
            }
            let scale: CGFloat = self.highlighted == .more ? 1.2 : 1
            self.moreButton.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    private func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else {
            return
        }

        isExpanded = expanded
        Haptics.play(expanded ? .menu : .tap)
        if expanded {
            collapsedTop = frame.minY
        }
        let height = expanded ? expandedHeight : Self.height
        let container = superview?.bounds.height ?? .greatestFiniteMagnitude
        let limit = container - (superview?.safeAreaInsets.bottom ?? 0) - 12
        let top = expanded ? min(collapsedTop, limit - height) : collapsedTop
        onExpand?(expanded)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0) {
            self.frame = CGRect(x: self.frame.minX, y: top, width: self.frame.width, height: height)
            self.layer.cornerRadius = expanded ? 22 : Self.height / 2
            self.chevron.transform = expanded ? CGAffineTransform(rotationAngle: .pi) : .identity
        }
        revealGrid(expanded)
    }

    private func revealGrid(_ expanded: Bool) {
        for index in quickCount..<labels.count {
            let label = labels[index]
            let row = (index - quickCount) / Self.columns
            label.transform = expanded ? CGAffineTransform(scaleX: 0.3, y: 0.3) : .identity
            UIView.animate(
                withDuration: expanded ? 0.4 : 0.15,
                delay: expanded ? 0.05 + Double(row) * 0.05 : 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0
            ) {
                label.alpha = expanded ? 1 : 0
                label.transform = .identity
            }
        }
        if let chosen = labels.firstIndex(where: { label in
            label.frame.insetBy(dx: 3, dy: 3) == chosenMark.frame
        }), chosen >= quickCount {
            UIView.animate(withDuration: 0.2) {
                self.chosenMark.alpha = expanded ? 1 : 0
            }
        }
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        switch hit(at: gesture.location(in: self)) {
        case .emoji(let index):
            Haptics.play(.selection)
            onPick?(emojis[index])
        case .more:
            setExpanded(!isExpanded)
        case nil:
            break
        }
    }
}
