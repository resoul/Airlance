import UIKit

extension QuickReplyCardView {
    var keyboardTop: CGFloat {
        let layer = keyboardTracker.layer.presentation() ?? keyboardTracker.layer

        return layer.frame.maxY
    }

    var isKeyboardMoving: Bool {
        !(keyboardTracker.layer.animationKeys()?.isEmpty ?? true)
    }

    func installKeyboardTracker() {
        keyboardTracker.isUserInteractionEnabled = false
        keyboardTracker.isHidden = true
        keyboardTracker.translatesAutoresizingMaskIntoConstraints = false
        addSubview(keyboardTracker)
        NSLayoutConstraint.activate([
            keyboardTracker.leadingAnchor.constraint(equalTo: leadingAnchor),
            keyboardTracker.widthAnchor.constraint(equalToConstant: 1),
            keyboardTracker.heightAnchor.constraint(equalToConstant: 1),
            keyboardTracker.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
        ])
    }
}
