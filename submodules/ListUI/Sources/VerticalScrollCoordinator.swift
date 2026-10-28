import UIKit

@MainActor
public final class VerticalScrollCoordinator {
    public private(set) var headerOffset: CGFloat = 0
    public private(set) var headerHeight: CGFloat
    public private(set) var paneOffset: CGFloat = 0
    public var viewportHeight: CGFloat = 600

    var onChange: (@MainActor () -> Void)?

    private weak var pane: (any ScrollablePane)?
    private var overscroll: CGFloat = 0
    private var isRendering = false

    public var isBouncing: Bool {
        abs(overscroll) > 0.1
    }

    public var topStretch: CGFloat {
        max(0, -elasticOffset)
    }

    public var isHeaderVisible: Bool {
        headerOffset < headerHeight - 0.5
    }

    private var elasticOffset: CGFloat {
        let distance = abs(overscroll)
        let dimension = max(1, viewportHeight)
        let amount = dimension * (1 - 1 / (1 + distance * 0.55 / dimension))

        return overscroll < 0 ? -amount : amount
    }

    init(headerHeight: CGFloat) {
        self.headerHeight = max(0, headerHeight)
    }

    public func setHeaderHeight(_ height: CGFloat, preservingContentPosition: Bool) {
        let next = max(0, height)
        let wasCollapsed = !isHeaderVisible
        let difference = next - headerHeight
        headerHeight = next
        if preservingContentPosition, headerOffset > 0 {
            headerOffset = min(headerHeight, max(0, headerOffset + difference))
        } else {
            headerOffset = wasCollapsed ? headerHeight : min(headerOffset, headerHeight)
        }
        render()
    }

    public func scrollToTop() {
        headerOffset = 0
        paneOffset = 0
        overscroll = 0
        render()
    }

    func activate(_ next: (any ScrollablePane)?) {
        if let next, let pane, next === pane {
            reconcile()

            return
        }

        pane?.setVerticalOffset(paneOffset)
        overscroll = 0
        pane = next
        let restored = min(max(0, next?.verticalOffset ?? 0), next?.maximumVerticalOffset ?? 0)
        paneOffset = isHeaderVisible ? 0 : restored
        render()
    }

    func reconcile() {
        guard !isRendering else {
            return
        }

        let offset = (pane?.verticalOffset ?? 0) - max(0, elasticOffset)
        paneOffset = min(max(0, offset), pane?.maximumVerticalOffset ?? 0)
        if paneOffset > 0 {
            headerOffset = headerHeight
        }
        render()
    }

    func consume(_ delta: CGFloat) {
        guard delta.isFinite else {
            return
        }

        var remaining = delta
        if overscroll * remaining < 0 {
            let repayment = min(abs(overscroll), abs(remaining)) * (remaining > 0 ? 1 : -1)
            overscroll += repayment
            remaining -= repayment
        }
        if abs(overscroll) > 0.01 {
            overscroll += remaining
        } else if remaining >= 0 {
            overscroll = scrollDown(remaining)
        } else {
            overscroll = -scrollUp(-remaining)
        }
        render()
    }

    func stepBounce(deltaTime: CGFloat, velocity: inout CGFloat) -> Bool {
        let previous = overscroll
        velocity += (-overscroll * 180 - velocity * 26) * deltaTime
        overscroll += velocity * deltaTime
        if previous * overscroll <= 0 || abs(overscroll) < 0.5 && abs(velocity) < 5 {
            overscroll = 0
            velocity = 0
        }
        render()

        return isBouncing
    }

    func finishBounce() {
        guard overscroll != 0 else {
            return
        }

        overscroll = 0
        render()
    }

    private func scrollDown(_ distance: CGFloat) -> CGFloat {
        let headerPart = min(distance, max(0, headerHeight - headerOffset))
        headerOffset += headerPart
        let panePart = min(distance - headerPart, max(0, (pane?.maximumVerticalOffset ?? 0) - paneOffset))
        paneOffset += panePart

        return distance - headerPart - panePart
    }

    private func scrollUp(_ distance: CGFloat) -> CGFloat {
        let panePart = min(distance, paneOffset)
        paneOffset -= panePart
        let headerPart = min(distance - panePart, headerOffset)
        headerOffset -= headerPart

        return distance - panePart - headerPart
    }

    private func render() {
        guard !isRendering else {
            return
        }

        isRendering = true
        pane?.setVerticalOffset(paneOffset + max(0, elasticOffset))
        onChange?()
        isRendering = false
    }
}
