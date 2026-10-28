@preconcurrency import AsyncDisplayKit
import UIKit

extension ListView {
    func configure(_ node: ListItemNode, at index: Int) {
        let item = items[index]
        let entry = entries[index]
        guard node.appliedVersion != entry.version || node.appliedWidth != layoutWidth else {
            return
        }

        item.update(node: node, theme: theme)
        node.appliedVersion = entry.version
        node.appliedWidth = layoutWidth
        guard
            let asyncItem = item as? any AsyncListItem,
            let layoutVersion = entry.layoutVersion,
            node.preparedLayoutVersion != layoutVersion || node.preparedWidth != layoutWidth
        else {
            return
        }

        node.layoutGeneration += 1
        node.layoutTask?.cancel()
        node.layoutTask = nil
        node.preparedLayoutVersion = layoutVersion
        node.preparedWidth = layoutWidth
        let id = itemIDs[index]
        if let layout = layouts.layout(for: id, layoutVersion: layoutVersion, width: layoutWidth) {
            asyncItem.apply(layout, to: node)
        } else {
            prepare(asyncItem, id: id, layoutVersion: layoutVersion, node: node)
        }
    }

    private func prepare(_ item: any AsyncListItem, id: String, layoutVersion: Int, node: ListItemNode) {
        let generation = node.layoutGeneration
        let work = preparation(for: item, id: id, layoutVersion: layoutVersion, priority: .userInitiated).task
        node.layoutTask = work

        Task { [weak node] in
            guard let layout = await work.value, let node, node.layoutGeneration == generation else {
                return
            }

            node.layoutTask = nil
            item.apply(layout, to: node)
        }
    }

    func preparation(
        for item: any AsyncListItem,
        id: String,
        layoutVersion: Int,
        priority: TaskPriority
    ) -> ListPreparation {
        if let existing = preparations[id], existing.layoutVersion == layoutVersion, existing.width == layoutWidth {
            return existing
        }

        preparations[id]?.task.cancel()
        let cacheGeneration = layouts.generation
        let width = layoutWidth
        let theme = theme
        let scale = view.traitCollection.displayScale
        let task = Task.detached(priority: priority) { () -> (any ListPreparedLayout)? in
            guard !Task.isCancelled else {
                return nil
            }

            return item.prepareLayout(width: width, theme: theme, displayScale: scale)
        }
        let preparation = ListPreparation(layoutVersion: layoutVersion, width: width, task: task)
        preparations[id] = preparation

        Task { [weak self] in
            let layout = await task.value
            guard let self else {
                return
            }

            if self.preparations[id]?.task == task {
                self.preparations[id] = nil
            }
            if let layout, self.layouts.generation == cacheGeneration {
                self.layouts.store(layout, for: id, layoutVersion: layoutVersion, width: width)
            }
            self.prefetchedRange = nil
            self.updatePrefetch()
        }

        return preparation
    }
}
