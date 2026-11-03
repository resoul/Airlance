import Haptics
import UIKit

extension StoriesHeaderView {
    static let createPressDuration: TimeInterval = 0.4

    func bindRowGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:)))
        let press = UILongPressGestureRecognizer(target: self, action: #selector(rowPressed(_:)))
        press.minimumPressDuration = Self.createPressDuration
        tap.require(toFail: press)
        rowScroll.addGestureRecognizer(tap)
        rowScroll.addGestureRecognizer(press)
    }

    private func entry(at point: CGPoint) -> StoryStripEntry? {
        let index = Int(((point.x - Self.rowInset) / Self.slotWidth).rounded(.down))
        guard entries.indices.contains(index), point.x >= Self.rowInset else {
            return nil
        }

        return entries[index]
    }

    private func bounce(_ entry: StoryStripEntry, scale: CGFloat) {
        UIView.animate(withDuration: 0.12, animations: {
            entry.container.transform = CGAffineTransform(scaleX: scale, y: scale)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                entry.container.transform = .identity
            }
        })
    }

    @objc
    private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let entry = entry(at: gesture.location(in: rowScroll)) else {
            return
        }

        Haptics.play(.tap)
        bounce(entry, scale: 0.9)
        if entry.peer.isSelf, entry.peer.storyCount == 0 {
            onCreate?()
        } else {
            onOpen?(entry.peer.id)
        }
    }

    @objc
    private func rowPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let entry = entry(at: gesture.location(in: rowScroll)), entry.peer.isSelf else {
            return
        }

        Haptics.play(.reveal)
        bounce(entry, scale: 1.12)
        onCreate?()
    }
}
