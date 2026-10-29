import Haptics
import UIKit

extension PopupMenu {
    public func track(_ point: CGPoint?, ended: Bool) {
        let target = point.flatMap(index(at:))
        if target != highlighted {
            highlight(target)
            if target != nil, !ended {
                Haptics.play(.selection)
            }
        }
        guard ended else {
            return
        }

        highlight(nil)
        if let target {
            let handler = items[target].handler
            close {
                handler()
            }
        }
    }

    public func location(of gesture: UIGestureRecognizer) -> CGPoint {
        gesture.location(in: panel)
    }

    @objc
    func pressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            Haptics.prepare(.selection)
            track(location(of: gesture), ended: false)
        case .changed:
            track(location(of: gesture), ended: false)
        case .ended:
            track(location(of: gesture), ended: true)
        default:
            track(nil, ended: true)
        }
    }

    private func index(at point: CGPoint) -> Int? {
        guard panel.bounds.contains(point) else {
            return nil
        }

        let index = Int(point.y / Self.rowHeight)

        return items.indices.contains(index) ? index : nil
    }

    private func highlight(_ index: Int?) {
        highlighted = index
        for (offset, view) in highlights.enumerated() {
            view.alpha = offset == index ? 1 : 0
        }
    }
}
