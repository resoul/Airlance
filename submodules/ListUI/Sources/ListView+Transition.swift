@preconcurrency import AsyncDisplayKit
import UIKit

extension ListView {
    func screenPositions() -> [String: CGFloat] {
        let offset = scrollView.contentOffset.y

        return active.mapValues { node in
            node.frame.minY - offset
        }
    }

    func keepOnScreen(_ ids: Set<String>, positions: [String: CGFloat]) {
        let offset = scrollView.contentOffset.y
        for id in ids {
            if let node = active[id], let position = positions[id] {
                node.frame.origin.y = position + offset
            }
        }
    }

    func settle(from positions: [String: CGFloat], inserted: Set<String>, animated: Bool) {
        UIView.performWithoutAnimation {
            updateVisible()
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled, let range = placedRange else {
            return
        }

        let shifts = shifts(from: positions, in: range)
        var moving: [(node: ListItemNode, frame: CGRect)] = []
        for index in range {
            guard let node = active[itemIDs[index]] else {
                continue
            }

            if inserted.contains(itemIDs[index]) {
                node.view.alpha = 0
            } else {
                node.frame = frames[index].offsetBy(dx: 0, dy: shift(shifts, at: index))
            }
            moving.append((node, frames[index]))
        }
        ListTransition.animate(true) {
            for (node, frame) in moving {
                node.frame = frame
                node.view.alpha = 1
            }
        }
    }

    private func shifts(from positions: [String: CGFloat], in range: Range<Int>) -> [(index: Int, shift: CGFloat)] {
        let offset = scrollView.contentOffset.y

        return range.compactMap { index in
            positions[itemIDs[index]].map { position in
                (index, position + offset - frames[index].minY)
            }
        }
    }

    private func shift(_ shifts: [(index: Int, shift: CGFloat)], at index: Int) -> CGFloat {
        let nearest = shifts.min { lhs, rhs in
            abs(lhs.index - index) < abs(rhs.index - index)
        }

        return nearest?.shift ?? 0
    }
}
