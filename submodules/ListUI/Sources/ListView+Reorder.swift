@preconcurrency import AsyncDisplayKit
import Haptics
import UIKit

struct ListReorder {
    let id: String
    let source: Int
    let run: ClosedRange<Int>
    let node: ListItemNode
    let grab: CGFloat
    var target: Int
}

extension ListView {
    func beginReorder(id: String, node: ListItemNode, location: CGPoint) -> Bool {
        guard let source = itemIDs.firstIndex(of: id), frames.indices.contains(source) else {
            return false
        }

        var lower = source
        while lower > 0, items[lower - 1].isMovable {
            lower -= 1
        }
        var upper = source
        while upper < items.count - 1, items[upper + 1].isMovable {
            upper += 1
        }
        reorder = ListReorder(
            id: id,
            source: source,
            run: lower...upper,
            node: node,
            grab: location.y - node.frame.minY,
            target: source
        )
        scrollView.isScrollEnabled = false
        node.view.layer.zPosition = 10
        node.view.layer.shadowColor = UIColor.black.cgColor
        node.view.layer.shadowOffset = CGSize(width: 0, height: 6)
        node.view.layer.shadowRadius = 14
        Haptics.play(.menu)
        UIView.animate(withDuration: 0.2) {
            node.view.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
            node.view.layer.shadowOpacity = 0.18
        }

        return true
    }

    func continueReorder(_ gesture: UILongPressGestureRecognizer) {
        guard var state = reorder else {
            return
        }

        switch gesture.state {
        case .changed:
            let lower = frames[state.run.lowerBound].minY
            let upper = frames[state.run.upperBound].maxY - frames[state.source].height
            let y = min(max(gesture.location(in: content.view).y - state.grab, lower), upper)
            state.node.view.center.y = y + frames[state.source].height / 2
            let target = reorderTarget(state, centerY: y + frames[state.source].height / 2)
            if target != state.target {
                state.target = target
                reorder = state
                Haptics.play(.selection)
                shiftNeighbours(state)
            }
        case .ended:
            finishReorder(state, commit: true)
        default:
            finishReorder(state, commit: false)
        }
    }

    private func reorderTarget(_ state: ListReorder, centerY: CGFloat) -> Int {
        var target = state.source
        for index in state.run.lowerBound..<state.source where centerY < frames[index].midY {
            target = index

            break
        }
        for index in (state.source + 1)...max(state.source + 1, state.run.upperBound)
            where index <= state.run.upperBound && centerY > frames[index].midY {
            target = index
        }

        return target
    }

    private func shift(for index: Int, in state: ListReorder) -> CGFloat {
        let height = frames[state.source].height
        if state.target < state.source, (state.target..<state.source).contains(index) {
            return height
        }
        if state.target > state.source, ((state.source + 1)...state.target).contains(index) {
            return -height
        }

        return 0
    }

    private func shiftNeighbours(_ state: ListReorder) {
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            for index in state.run where index != state.source {
                self.active[self.itemIDs[index]]?.frame = self.frames[index].offsetBy(
                    dx: 0,
                    dy: self.shift(for: index, in: state)
                )
            }
        }
    }

    private func finishReorder(_ state: ListReorder, commit: Bool) {
        let target = commit ? state.target : state.source
        var finished = state
        finished.target = target
        let height = frames[state.source].height
        let landing = target < state.source ? frames[target].minY : frames[target].maxY - height
        reorder = nil
        scrollView.isScrollEnabled = true
        shiftNeighbours(finished)
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            state.node.view.center.y = landing + height / 2
            state.node.view.transform = .identity
            state.node.view.layer.shadowOpacity = 0
        } completion: { _ in
            state.node.view.layer.zPosition = 0
        }
        if target != state.source {
            Haptics.play(.selection)
            onMove?(state.id, target)
        }
    }
}
