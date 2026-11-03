import CoreGraphics

@MainActor
public final class StoriesExpansion {
    public let rowHeight: CGFloat
    public var baseInset: CGFloat = 0
    public var isEnabled = true {
        didSet {
            if !isEnabled, isExpanded {
                setExpanded(false)
            }
        }
    }
    public var onInsetChange: (@MainActor (CGFloat) -> Void)?

    public private(set) var isExpanded = false

    private var anchor: (offset: CGFloat, fraction: CGFloat)?

    public init(rowHeight: CGFloat) {
        self.rowHeight = rowHeight
    }

    public var topInset: CGFloat {
        baseInset + (isExpanded ? rowHeight : 0)
    }

    public func fraction(offset: CGFloat) -> CGFloat {
        guard isEnabled, rowHeight > 0 else {
            return 0
        }

        let absolute = absoluteFraction(offset: offset)
        guard let detached = detachedFraction(offset: offset), detached > absolute else {
            return absolute
        }

        return detached
    }

    public func keep(fraction: CGFloat, at offset: CGFloat) {
        guard isEnabled, isExpanded, fraction > absoluteFraction(offset: offset) else {
            anchor = nil

            return
        }

        anchor = (offset, fraction)
    }

    public func didScroll(offset: CGFloat) {
        guard isExpanded else {
            return
        }

        if let detached = detachedFraction(offset: offset) {
            if detached <= absoluteFraction(offset: offset) {
                anchor = nil
            } else if detached <= 0 {
                setExpanded(false)
            }

            return
        }

        if offset >= -baseInset {
            setExpanded(false)
        }
    }

    private func absoluteFraction(offset: CGFloat) -> CGFloat {
        let overscroll = -offset - topInset
        let value = isExpanded ? 1 + overscroll / rowHeight : overscroll / rowHeight

        return min(max(value, 0), 1)
    }

    private func detachedFraction(offset: CGFloat) -> CGFloat? {
        anchor.map { anchor in
            min(max(anchor.fraction - (offset - anchor.offset) / rowHeight, 0), 1)
        }
    }

    public func targetOffset(from offset: CGFloat, proposed target: CGFloat) -> CGFloat {
        guard isEnabled, anchor == nil else {
            return target
        }

        if !isExpanded {
            guard fraction(offset: offset) > 0.4 else {
                return target
            }

            setExpanded(true)

            return -topInset
        }

        let top = -topInset
        guard target > top, target < top + rowHeight else {
            return target
        }

        return target < top + rowHeight / 2 ? top : top + rowHeight
    }

    public func expand() {
        setExpanded(true)
    }

    private func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else {
            return
        }

        isExpanded = expanded
        anchor = nil
        onInsetChange?(topInset)
    }
}
