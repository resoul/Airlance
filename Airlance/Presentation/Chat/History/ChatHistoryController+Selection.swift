import ChatHistory
import Haptics
import LiquidUI
import UIKit

extension ChatHistoryController {
    var isSelecting: Bool {
        selection != nil
    }

    func startSelecting(with id: String) {
        guard selection == nil, message(id)?.content.isService == false else {
            return
        }

        selection = [id]
        selectionPan.install(on: listView.scrollView)
        Haptics.play(.selection)
        selectionChanged(movesAvatars: true)
    }

    func endSelecting() {
        guard selection != nil else {
            return
        }

        selection = nil
        selectionChanged(movesAvatars: true)
    }

    func toggleSelection(_ id: String) {
        guard let selection else {
            return
        }

        setSelected(id, !selection.contains(id))
    }

    func setSelected(_ id: String, _ isSelected: Bool) {
        guard var selection, selection.contains(id) != isSelected, message(id)?.content.isService == false else {
            return
        }

        if isSelected {
            selection.insert(id)
        } else {
            selection.remove(id)
        }
        self.selection = selection
        Haptics.play(.selection)
        selectionChanged(movesAvatars: false)
    }

    var selectedMessages: [HistoryMessage] {
        let ids = selection ?? []

        let messages = store.history(for: chatID)?.messages ?? window.data.messages

        return messages.filter { message in
            ids.contains(message.id)
        }
    }

    func reapplyItems() {
        if let lastSnapshot, let style {
            listView.apply(items: items(lastSnapshot, style: style), animated: false)
        }
    }

    private func selectionChanged(movesAvatars: Bool) {
        reapplyItems()
        if movesAvatars {
            avatars.shift = isSelecting ? MessageBubbleNode.selectionInset : 0
            UIView.animate(withDuration: 0.3) {
                self.avatars.update(in: self.listView)
            }
        }
        onSelectionChange?(selection)
    }
}

@MainActor
final class HistorySelectionPan: NSObject, UIGestureRecognizerDelegate {
    private static let column: CGFloat = 56
    private static let edge: CGFloat = 80
    private static let maxSpeed: CGFloat = 1100

    private weak var controller: ChatHistoryController?
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
    private var target = true
    private var visited: Set<String> = []
    private var finger: CGPoint?
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.autoscroll(deltaTime)
    }

    init(controller: ChatHistoryController) {
        self.controller = controller
    }

    func install(on view: UIScrollView) {
        guard pan.view == nil else {
            return
        }

        pan.delegate = self
        view.addGestureRecognizer(pan)
        view.panGestureRecognizer.require(toFail: pan)
    }

    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard let controller, controller.isSelecting, let view = gesture.view else {
            return false
        }

        let point = gesture.location(in: view.superview)
        let velocity = pan.velocity(in: view)

        return point.x < Self.column && abs(velocity.y) > abs(velocity.x)
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        guard let controller, let view = gesture.view else {
            return
        }

        let id = controller.listView.itemID(at: gesture.location(in: view), in: view)
        finger = gesture.location(in: view.superview)
        switch gesture.state {
        case .began:
            visited = []
            target = !(id.map { id in
                controller.selection?.contains(id) ?? false
            } ?? false)
            mark(id, in: controller)
            driver.start()
        case .changed:
            mark(id, in: controller)
        default:
            visited = []
            finger = nil
            driver.stop()
        }
    }

    private func autoscroll(_ deltaTime: CFTimeInterval) {
        guard let controller, let view = pan.view as? UIScrollView, let finger, let container = view.superview else {
            return
        }

        let insets = view.adjustedContentInset
        let top = view.frame.minY + insets.top
        let bottom = view.frame.maxY - insets.bottom
        var speed: CGFloat = 0
        if finger.y < top + Self.edge {
            speed = -min(1, (top + Self.edge - finger.y) / Self.edge)
        } else if finger.y > bottom - Self.edge {
            speed = min(1, (finger.y - bottom + Self.edge) / Self.edge)
        }
        guard speed != 0 else {
            return
        }

        let minY = -insets.top
        let maxY = max(minY, view.contentSize.height - view.bounds.height + insets.bottom)
        let next = min(max(minY, view.contentOffset.y + speed * Self.maxSpeed * CGFloat(deltaTime)), maxY)
        guard next != view.contentOffset.y else {
            return
        }

        view.contentOffset.y = next
        let point = container.convert(finger, to: view)
        mark(controller.listView.itemID(at: point, in: view), in: controller)
    }

    private func mark(_ id: String?, in controller: ChatHistoryController) {
        guard let id, !visited.contains(id) else {
            return
        }

        visited.insert(id)
        controller.setSelected(id, target)
    }
}
