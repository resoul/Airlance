import Haptics
import UIKit

extension ChatInputBar {
    private static let scheduledSide: CGFloat = 34
    static let scheduledInset: CGFloat = 30

    func setupScheduledButton() {
        let image = UIImage(systemName: "clock.arrow.circlepath", withConfiguration: Self.symbol(19))
        scheduledButton.setImage(image, for: .normal)
        scheduledButton.isHidden = true
        scheduledButton.addAction(
            UIAction { [weak self] _ in
                Haptics.play(.tap)
                self?.onScheduled?()
            },
            for: .touchUpInside
        )
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(scheduledHeld(_:)))
        hold.minimumPressDuration = 0.3
        scheduledButton.addGestureRecognizer(hold)
        fieldBox.addSubview(scheduledButton)
    }

    func setScheduledCount(_ count: Int, tint: UIColor, label: String) {
        scheduledCount = count
        scheduledButton.tintColor = tint
        scheduledButton.accessibilityLabel = label
        updateScheduledVisibility()
    }

    func updateScheduledVisibility() {
        let isHidden = scheduledCount == 0 && (!hasText || isEditingMessage)
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
            frame.size.width -= Self.scheduledInset
            scheduledButton.frame = CGRect(
                x: fieldBox.bounds.width - side - 4,
                y: fieldBox.bounds.height - side - (Self.controlSize - side) / 2,
                width: side,
                height: side
            )
        }
        textView.frame = frame
    }

    @objc
    private func scheduledHeld(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            onScheduledHold?()
        }
    }
}
