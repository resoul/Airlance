import UIKit

extension ChatInputBar {
    private static let scheduledSide: CGFloat = 34

    func setupScheduledButton() {
        scheduledButton.setImage(UIImage(systemName: "calendar.badge.clock"), for: .normal)
        scheduledButton.isHidden = true
        scheduledButton.addAction(
            UIAction { [weak self] _ in
                self?.onScheduled?()
            },
            for: .touchUpInside
        )
        fieldBox.addSubview(scheduledButton)
    }

    func setScheduledCount(_ count: Int, tint: UIColor, label: String) {
        let isHidden = count == 0
        scheduledButton.tintColor = tint
        scheduledButton.accessibilityLabel = label
        guard scheduledButton.isHidden != isHidden else {
            return
        }

        scheduledButton.isHidden = isHidden
        setNeedsLayout()
    }

    func layoutField() {
        let side = Self.scheduledSide
        var frame = fieldBox.bounds
        if !scheduledButton.isHidden {
            frame.size.width -= side - 4
            scheduledButton.frame = CGRect(
                x: fieldBox.bounds.width - side - 2,
                y: fieldBox.bounds.height - side - 1,
                width: side,
                height: side
            )
        }
        textView.frame = frame
    }
}
