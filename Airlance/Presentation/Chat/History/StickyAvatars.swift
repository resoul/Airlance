@preconcurrency import AsyncDisplayKit
import AvatarUI
import ListUI
import UIKit

@MainActor
final class StickyAvatars {
    private static let preload: CGFloat = 240

    private var series: [AvatarSeries] = []
    private var visible: [String: AvatarNode] = [:]
    private var pool: [AvatarNode] = []

    func setSeries(_ series: [AvatarSeries], in list: ListView) {
        self.series = series
        update(in: list)
    }

    func update(in list: ListView) {
        let area = list.visibleContentRect
        let size = MessageBubbleLayout.avatarSize
        var used = Set<String>()
        for item in series {
            guard let first = list.itemFrame(at: item.firstRow), let last = list.itemFrame(at: item.lastRow) else {
                continue
            }

            let top = first.minY + item.topInset
            let bottom = last.minY + item.bottomInset
            guard bottom > area.minY - Self.preload, top < area.maxY + Self.preload else {
                continue
            }

            let node = node(for: item, in: list)
            let y = max(top, min(bottom, area.maxY) - size)
            node.frame = CGRect(x: MessageBubbleLayout.sideInset, y: y, width: size, height: size)
            node.isOnScreen = bottom > area.minY && top < area.maxY
            used.insert(item.id)
        }
        for (id, node) in visible where !used.contains(id) {
            visible.removeValue(forKey: id)
            node.view.removeFromSuperview()
            node.prepareForReuse()
            pool.append(node)
        }
    }

    private func node(for item: AvatarSeries, in list: ListView) -> AvatarNode {
        if let node = visible[item.id] {
            return node
        }

        let node = pool.popLast() ?? AvatarNode()
        node.apply(PeerAvatars.descriptor(id: item.authorID, name: item.authorName))
        list.overlayView.addSubview(node.view)
        visible[item.id] = node

        return node
    }
}
