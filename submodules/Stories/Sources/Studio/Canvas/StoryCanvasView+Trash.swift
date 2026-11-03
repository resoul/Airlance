import Haptics
import UIKit

extension StoryCanvasView {
    func setUpTrash() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        trash.image = UIImage(systemName: "trash", withConfiguration: configuration)
        trash.contentMode = .center
        trash.tintColor = .white
        trash.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        trash.bounds = CGRect(x: 0, y: 0, width: 54, height: 54)
        trash.layer.cornerRadius = 27
        trash.isUserInteractionEnabled = false
        trash.isHidden = true
        addSubview(trash)
    }

    func dragged(_ view: UIView, state: UIGestureRecognizer.State, at point: CGPoint) -> Bool {
        switch state {
        case .began:
            trash.alpha = 0
            trash.isHidden = false
            bringSubviewToFront(trash)
            setGuidesVisible(true)
            onDragging?(true)
            UIView.animate(withDuration: 0.2) {
                self.trash.alpha = 1
            }
        case .changed:
            setOverTrash(isOverTrash(point), view: view)
        case .ended, .cancelled:
            let drops = state == .ended && isOverTrash(point)
            hideTrash()
            setGuidesVisible(false)
            view.alpha = 1
            onDragging?(false)

            return drops
        default:
            break
        }

        return false
    }

    private func isOverTrash(_ point: CGPoint) -> Bool {
        trash.frame.insetBy(dx: -24, dy: -24).contains(point)
    }

    private func setOverTrash(_ isOver: Bool, view: UIView) {
        let wasOver = trash.transform != .identity
        guard isOver != wasOver else {
            return
        }

        Haptics.play(.selection)
        UIView.animate(withDuration: 0.18) {
            self.trash.transform = isOver ? CGAffineTransform(scaleX: 1.25, y: 1.25) : .identity
            self.trash.backgroundColor = isOver ? .systemRed : UIColor.black.withAlphaComponent(0.45)
            view.alpha = isOver ? 0.45 : 1
        }
    }

    private func hideTrash() {
        UIView.animate(withDuration: 0.2) {
            self.trash.alpha = 0
            self.trash.transform = .identity
            self.trash.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        } completion: { _ in
            self.trash.isHidden = true
        }
    }
}
