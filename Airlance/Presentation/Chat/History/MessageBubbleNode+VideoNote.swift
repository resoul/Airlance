@preconcurrency import AsyncDisplayKit
import UIKit

extension MessageBubbleNode {
    func applyVideoNote(_ layout: MessageBubbleLayout) {
        guard let parts = layout.videoNote, isNodeLoaded else {
            videoNoteView?.removeFromSuperview()
            videoNoteView = nil

            return
        }

        if videoNoteView?.note != parts.note {
            videoNoteView?.removeFromSuperview()
            videoNoteView = VideoNoteView(note: parts.note, accent: .white)
        }
        guard let noteView = videoNoteView else {
            return
        }

        noteView.frame = parts.frame.offsetBy(dx: layout.bubbleFrame.minX, dy: layout.bubbleFrame.minY)
        if noteView.superview !== view {
            view.addSubview(noteView)
        }
        view.layer.insertSublayer(noteView.layer, below: layout.content.layer)
    }

    func toggleVideoNote() {
        videoNoteView?.toggle()
    }
}
