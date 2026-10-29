import UIKit

public struct ListAnchor: Sendable, Equatable {
    public let id: String
    public let distance: CGFloat

    public init(id: String, distance: CGFloat) {
        self.id = id
        self.distance = distance
    }
}

extension ListView {
    public var distanceToBottom: CGFloat {
        distanceFromBottom(insets: contentInsets)
    }

    public var isNearBottom: Bool {
        distanceToBottom < 8
    }

    public func currentAnchor() -> ListAnchor? {
        let top = visibleContentRect.minY
        guard let index = frames.firstIndex(where: { frame in
            frame.maxY > top
        }) else {
            return nil
        }

        return ListAnchor(id: itemIDs[index], distance: frames[index].minY - top)
    }

    public var visibleItemIDs: [String] {
        guard isNodeLoaded else {
            return []
        }

        let range = visibleIndices(margin: 0)

        return range.upperBound <= itemIDs.count ? Array(itemIDs[range]) : []
    }

    public func anchor(for id: String) -> ListAnchor? {
        frame(for: id).map { frame in
            ListAnchor(id: id, distance: frame.minY - visibleContentRect.minY)
        }
    }

    public func scroll(to anchor: ListAnchor) {
        pendingAnchor = anchor
        if isNodeLoaded, layoutWidth > 0, frames.count == items.count, applyPendingAnchor() {
            updateVisible()
        }
    }

    func applyPendingAnchor() -> Bool {
        guard let anchor = pendingAnchor else {
            return false
        }

        pendingAnchor = nil
        guard let index = itemIDs.firstIndex(of: anchor.id), frames.indices.contains(index) else {
            return false
        }

        restoreOffset(frames[index].minY - anchor.distance - contentInsets.top)

        return true
    }

    public var distanceFromTop: CGFloat {
        scrollView.contentOffset.y + contentInsets.top
    }

    public var visibleContentRect: CGRect {
        let top = scrollView.contentOffset.y + contentInsets.top
        let height = scrollView.bounds.height - contentInsets.top - contentInsets.bottom

        return CGRect(x: 0, y: top, width: scrollView.bounds.width, height: max(0, height))
    }

    public func itemFrame(at index: Int) -> CGRect? {
        frames.indices.contains(index) ? frames[index] : nil
    }

    public func node(for id: String) -> ListItemNode? {
        active[id]
    }

    public func node(atContentPoint point: CGPoint) -> ListItemNode? {
        active.values.first { node in
            node.frame.contains(point)
        }
    }

    public func frame(for id: String) -> CGRect? {
        itemIDs.firstIndex(of: id).flatMap { index in
            frames.indices.contains(index) ? frames[index] : nil
        }
    }

    public func contains(_ id: String) -> Bool {
        itemIDs.contains(id)
    }

    public func scrollToItem(_ id: String, animated: Bool) {
        guard let index = itemIDs.firstIndex(of: id), frames.indices.contains(index) else {
            return
        }

        let visible = visibleContentRect.height
        let frame = frames[index]
        let target = frame.midY - contentInsets.top - visible / 2
        let minimum = -contentInsets.top
        let offset = min(max(minimum, target), maximumOffset(insets: contentInsets))
        scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: animated)
    }

    public func scrollToBottom(animated: Bool) {
        let offset = CGPoint(x: 0, y: maximumOffset(insets: contentInsets))
        scrollView.setContentOffset(offset, animated: animated)
    }

    func maximumOffset(insets: UIEdgeInsets) -> CGFloat {
        max(-insets.top, scrollView.contentSize.height + insets.bottom - scrollView.bounds.height)
    }

    func distanceFromBottom(insets: UIEdgeInsets) -> CGFloat {
        guard scrollView.contentSize.height > 0, scrollView.bounds.height > 0 else {
            return 0
        }

        return max(0, maximumOffset(insets: insets) - scrollView.contentOffset.y)
    }

    func bottomFill(contentHeight: CGFloat) -> CGFloat {
        guard anchorsToBottom else {
            return 0
        }

        return max(0, scrollView.bounds.height - contentInsets.top - contentInsets.bottom - contentHeight)
    }

    func keepBottom(distance: CGFloat) {
        guard isNodeLoaded, layoutWidth > 0 else {
            return
        }

        relayoutContent()
        guard !scrollView.isTracking, !scrollView.isDecelerating else {
            return
        }

        restoreOffset(maximumOffset(insets: contentInsets) - distance)
    }
}
