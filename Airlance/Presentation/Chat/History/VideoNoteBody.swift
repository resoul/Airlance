@preconcurrency import AsyncDisplayKit
import ChatHistory
import UIKit

struct VideoNoteParts {
    let frame: CGRect
    let note: MessageVideoNote
}

struct VideoNoteBody {
    let note: MessageVideoNote
    let input: MessageBubbleInput
    let scale: CGFloat

    static func size(for style: MessageVideoNote.Style) -> CGSize {
        switch style {
        case .dualCamera:
            CGSize(width: 220, height: 292)
        case .reaction:
            CGSize(width: 180, height: 180)
        case .blob, .anonymous, .moment:
            CGSize(width: 220, height: 220)
        }
    }

    static func cornerRadius(for style: MessageVideoNote.Style, size: CGSize) -> CGFloat {
        switch style {
        case .dualCamera:
            22
        case .moment:
            28
        case .blob, .anonymous, .reaction:
            min(size.width, size.height) / 2
        }
    }

    func make(style: HistoryStyle) -> BubbleBody {
        let size = Self.size(for: note.style)
        let frame = CGRect(origin: .zero, size: size)
        let content = ASDisplayNode()
        content.isLayerBacked = true
        var body = BubbleBody(size: size, content: content)
        let message = input.message
        let delivery = message.isOutgoing ? message.delivery : nil
        let meta = MessageMeta(input, delivery: delivery, style: style, onMedia: true)
        meta.place(in: content, bottomRight: CGPoint(x: size.width - 10, y: size.height - 8))
        content.frame = frame
        body.actions.append(BubbleAction(frame: frame, kind: .videoNote))
        body.videoNote = VideoNoteParts(frame: frame, note: note)

        return body
    }
}
