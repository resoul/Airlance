import AirlanceUI
import Haptics
import UIKit

extension CameraViewController {
    func setUpModes() {
        let modes = availableModes
        mode = modes[0]
        modeControl.isHidden = modes.count < 2
        modeControl.apply(style: LiquidSegmentedStyle(
            font: .systemFont(ofSize: 14, weight: .semibold),
            text: .white,
            selectedText: .black,
            background: UIColor.black.withAlphaComponent(0.4),
            accent: .systemYellow
        ))
        modeControl.setTitles(modes.map { mode in
            configuration.strings.modes[mode] ?? ""
        })
        modeControl.select(0, animated: false)
        modeControl.onSelect = { [weak self] index in
            self?.selectMode(at: index)
        }
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipedMode(_:)))
            swipe.direction = direction
            previewHost.addGestureRecognizer(swipe)
        }
        burstLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        burstLabel.textColor = .black
        burstLabel.textAlignment = .center
        burstLabel.backgroundColor = .systemYellow
        burstLabel.clipsToBounds = true
        burstLabel.alpha = 0
        squareMask.alpha = 0
        applyMode(animated: false)
    }

    var canChangeMode: Bool {
        !isRecordingVideo && !isBursting && !isProcessing
    }

    func selectMode(at index: Int) {
        let modes = availableModes
        guard modes.indices.contains(index), canChangeMode, modes[index] != mode else {
            modeControl.select(modes.firstIndex(of: mode) ?? 0, animated: true)

            return
        }

        mode = modes[index]
        modeControl.select(index, animated: true)
        applyMode(animated: true)
    }

    private func applyMode(animated: Bool) {
        shutter.setMode(mode)
        if mode == .dual {
            enterDual()
        } else {
            leaveDual()
        }
        let changes = {
            self.squareMask.alpha = self.mode == .square ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.25, animations: changes)
        } else {
            changes()
        }
    }

    @objc
    private func swipedMode(_ gesture: UISwipeGestureRecognizer) {
        let modes = availableModes
        guard modes.count > 1, let current = modes.firstIndex(of: mode) else {
            return
        }

        let next = current + (gesture.direction == .left ? 1 : -1)
        guard modes.indices.contains(next) else {
            return
        }

        Haptics.play(.selection)
        selectMode(at: next)
    }
}
