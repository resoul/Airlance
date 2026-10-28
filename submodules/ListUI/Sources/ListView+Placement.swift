@preconcurrency import AsyncDisplayKit
import UIKit

extension ListView {
    func updateVisible() {
        guard !isSuspended, layoutWidth > 0, frames.count == items.count else {
            return
        }

        let indices = visibleIndices(margin: Self.preloadDistance)
        guard indices != placedRange else {
            updateShown()
            updatePrefetch()

            return
        }

        placedRange = indices
        shownRange = nil
        let visibleIDs = Set(indices.map { index in
            itemIDs[index]
        })
        for id in Array(active.keys) where !visibleIDs.contains(id) {
            if let node = active.removeValue(forKey: id) {
                recycle(node)
            }
        }

        for index in indices {
            place(at: index)
        }
        updateShown()
        updatePrefetch()
    }

    func place(at index: Int) {
        let id = itemIDs[index]
        let reuseIdentifier = entries[index].reuseIdentifier
        if let existing = active[id], existing.reuseIdentifier == reuseIdentifier {
            configure(existing, at: index)
            if existing.frame != frames[index] {
                existing.frame = frames[index]
            }
            existing.view.alpha = 1

            return
        }

        if let old = active.removeValue(forKey: id) {
            recycle(old)
        }
        let node = pool[reuseIdentifier]?.popLast() ?? items[index].makeNode()
        node.reuseIdentifier = reuseIdentifier
        node.itemID = id
        node.view.isUserInteractionEnabled = true
        active[id] = node
        if node.supernode !== content {
            content.addSubnode(node)
        }

        UIView.performWithoutAnimation {
            configure(node, at: index)
            node.frame = frames[index]
            node.view.alpha = 1
            node.isHidden = false
        }
    }

    func recycle(_ node: ListItemNode) {
        swipe?.nodeWillRecycle(node)
        let kind = node.reuseIdentifier
        node.prepareForReuse()
        guard pool[kind, default: []].count < Self.poolLimit else {
            node.removeFromSupernode()

            return
        }

        node.isHidden = true
        pool[kind, default: []].append(node)
    }

    func fadeOut(_ deleted: Set<String>, animated: Bool) {
        for id in deleted {
            layouts.remove(id)
            preparations.removeValue(forKey: id)?.task.cancel()
            guard let node = active.removeValue(forKey: id) else {
                continue
            }

            node.view.isUserInteractionEnabled = false
            node.layoutGeneration += 1
            node.layoutTask?.cancel()
            node.isOnScreen = false
            ListTransition.animate(animated) {
                node.view.alpha = 0
            } completion: { [weak self] _ in
                self?.recycle(node)
            }
        }
    }
}
