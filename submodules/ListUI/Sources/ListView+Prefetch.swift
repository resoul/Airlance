import UIKit

struct ListPreparation {
    let layoutVersion: Int
    let width: CGFloat
    let task: Task<(any ListPreparedLayout)?, Never>
}

extension ListView {
    private static let prefetchLimit = 4

    func updatePrefetch() {
        guard isNodeLoaded, isOnScreen, layoutWidth > 0, frames.count == items.count else {
            return
        }

        let range = visibleIndices(margin: max(600, scrollView.bounds.height * 2))
        guard range != prefetchedRange else {
            return
        }

        prefetchedRange = range
        cancelPreparations(outside: range)
        let visible = visibleIndices(margin: 0)
        let center = visible.isEmpty ? range.lowerBound : (visible.lowerBound + visible.upperBound) / 2
        let ordered = range.sorted { lhs, rhs in
            abs(lhs - center) < abs(rhs - center)
        }
        for index in ordered where preparations.count < Self.prefetchLimit {
            prefetch(at: index)
        }
    }

    func resetLayouts() {
        layouts.removeAll()
        for preparation in preparations.values {
            preparation.task.cancel()
        }
        preparations = [:]
        prefetchedRange = nil
    }

    private func prefetch(at index: Int) {
        guard let item = items[index] as? any AsyncListItem, let layoutVersion = entries[index].layoutVersion else {
            return
        }

        let id = itemIDs[index]
        guard preparations[id] == nil, !layouts.contains(id, layoutVersion: layoutVersion, width: layoutWidth) else {
            return
        }

        if let node = active[id], node.layoutTask == nil, node.preparedLayoutVersion == layoutVersion,
           node.preparedWidth == layoutWidth {
            return
        }

        _ = preparation(for: item, id: id, layoutVersion: layoutVersion, priority: .utility)
    }

    private func cancelPreparations(outside range: Range<Int>) {
        guard !preparations.isEmpty else {
            return
        }

        let wanted = Set(range.map { index in
            itemIDs[index]
        })
        for (id, preparation) in preparations where !wanted.contains(id) && active[id] == nil {
            preparation.task.cancel()
            preparations.removeValue(forKey: id)
        }
    }
}
