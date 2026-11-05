import AvatarUI
import UIKit

final class ProfilePhotoStrip: UIScrollView {
    private static let side: CGFloat = 40
    private static let gap: CGFloat = 4

    var onSelect: (@MainActor (Int) -> Void)?

    private var cells: [UIControl] = []

    func show(_ photos: [AvatarDescriptor], selected: Int) {
        for cell in cells {
            cell.removeFromSuperview()
        }
        cells = photos.enumerated().map { index, descriptor in
            makeCell(descriptor, index: index)
        }
        setSelected(selected)
        setNeedsLayout()
    }

    func setSelected(_ index: Int) {
        for (position, cell) in cells.enumerated() {
            cell.layer.borderWidth = position == index ? 2 : 0
            cell.alpha = position == index ? 1 : 0.6
        }
        guard cells.indices.contains(index) else {
            return
        }

        layoutIfNeeded()
        let target = cells[index].center.x - bounds.width / 2
        let limit = max(0, contentSize.width - bounds.width)
        setContentOffset(CGPoint(x: min(max(0, target), limit), y: 0), animated: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let total = CGFloat(cells.count) * (Self.side + Self.gap) - Self.gap
        contentSize = CGSize(width: max(total, 0), height: bounds.height)
        var x = max(0, (bounds.width - total) / 2)
        for cell in cells {
            cell.frame = CGRect(x: x, y: (bounds.height - Self.side) / 2, width: Self.side, height: Self.side)
            cell.subviews.first?.frame = cell.bounds
            x += Self.side + Self.gap
        }
    }

    private func makeCell(_ descriptor: AvatarDescriptor, index: Int) -> UIControl {
        let cell = UIControl()
        cell.layer.cornerRadius = 6
        cell.layer.borderColor = UIColor.white.cgColor
        cell.clipsToBounds = true
        let avatar = AvatarNode()
        avatar.isUserInteractionEnabled = false
        avatar.contentCornerRadius = 0
        avatar.apply(descriptor, presentation: .still)
        cell.addSubview(avatar.view)
        cell.addAction(
            UIAction { [weak self] _ in
                self?.onSelect?(index)
            },
            for: .touchUpInside
        )
        addSubview(cell)

        return cell
    }
}
