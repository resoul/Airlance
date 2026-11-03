import UIKit

extension MessageBubbleNode {
    func applyTransfer(_ progress: TransferProgress?) {
        guard let layout = layoutResult, let slots = layout.transfer else {
            removeTransfer()

            return
        }

        let frames: [CGRect]
        switch progress?.direction {
        case .upload:
            frames = slots.all
        case .download:
            frames = slots.pending
        case nil:
            frames = slots.showsIdle ? slots.pending : []
        }
        while transferIndicators.count > frames.count {
            transferIndicators.removeLast().removeFromSuperlayer()
        }
        while transferIndicators.count < frames.count {
            let indicator = TransferIndicator()
            layer.addSublayer(indicator)
            transferIndicators.append(indicator)
        }
        let origin = layout.bubbleFrame.origin
        let scale = view.traitCollection.displayScale
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (indicator, frame) in zip(transferIndicators, frames) {
            indicator.place(in: frame.offsetBy(dx: origin.x, dy: origin.y), scale: scale)
            indicator.show(progress, reduceMotion: reduceMotion)
        }
        CATransaction.commit()
    }

    func removeTransfer() {
        for indicator in transferIndicators {
            indicator.removeFromSuperlayer()
        }
        transferIndicators = []
    }
}
