import UIKit

extension ChatInputBar {
    func showPanel(_ content: ChatPanelContent) {
        replyPanel.show(content)
        let wasShown = showsReply
        showsReply = true
        if !wasShown {
            replyPanel.transform = CGAffineTransform(translationX: 0, y: 24)
        }
        animateLayout {
            self.replyPanel.alpha = 1
            self.replyPanel.transform = .identity
        }
    }

    func hidePanel() {
        guard showsReply else {
            return
        }

        showsReply = false
        animateLayout {
            self.replyPanel.alpha = 0
            self.replyPanel.transform = CGAffineTransform(translationX: 0, y: 24)
        }
    }

    var isVideoMessage: Bool {
        isVideoMode
    }

    var actionCenter: CGPoint {
        CGPoint(x: actionIcon.frame.midX, y: actionIcon.frame.midY)
    }

    func setRecording(_ isRecording: Bool) {
        UIView.animate(withDuration: 0.2) {
            for view in [self.attachButton, self.fieldBox, self.actionIcon] as [UIView] {
                view.alpha = isRecording ? 0 : 1
            }
        }
    }

    @objc
    func held(_ gesture: UILongPressGestureRecognizer) {
        guard !hasText, !isEditingMessage else {
            return
        }

        onHold?(gesture)
    }
}
