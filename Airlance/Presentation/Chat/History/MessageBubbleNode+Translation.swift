@preconcurrency import AsyncDisplayKit
import EffectsUI
import UIKit

extension MessageBubbleNode {
    func dissolveText() -> Bool {
        guard let layout = textLayout, isNodeLoaded, view.window != nil else {
            return false
        }

        var rect = layout.node.frame
        if let note = translationNote {
            rect = rect.union(note.frame)
        }
        rect = rect.offsetBy(dx: layout.origin.x, dy: layout.origin.y)
        guard ViewEffects.play(.dissolve, on: view, rect: rect) else {
            return false
        }

        layout.node.isHidden = true
        translationNote?.isHidden = true

        return true
    }

    func revealText() {
        guard let text = textLayout?.node else {
            return
        }

        let length = text.attributedText?.length ?? 0
        let lines = text.rects(forTextRange: NSRange(location: 0, length: length)).map(\.cgRectValue)
        let total = lines.reduce(0) { sum, line in
            sum + line.width
        }
        guard total > 0 else {
            return
        }

        let duration = min(1.1, max(0.4, Double(total) / 650))
        let mask = CALayer()
        mask.frame = text.bounds
        var start = CACurrentMediaTime()
        for line in lines {
            let share = duration * Double(line.width / total)
            mask.addSublayer(Self.revealPiece(line, begin: start, duration: share))
            start += share
        }
        text.layer.mask = mask
        fadeInNote()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { [weak text] in
            text?.layer.mask = nil
        }
    }

    private func fadeInNote() {
        guard let note = translationNote else {
            return
        }

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.3
        note.layer.add(fade, forKey: "reveal")
    }

    private static func revealPiece(_ line: CGRect, begin: CFTimeInterval, duration: CFTimeInterval) -> CALayer {
        let tail: CGFloat = 24
        let frame = CGRect(x: line.minX, y: line.minY - 1, width: line.width + tail, height: line.height + 2)
        let piece = CAGradientLayer()
        piece.startPoint = CGPoint(x: 0, y: 0.5)
        piece.endPoint = CGPoint(x: 1, y: 0.5)
        piece.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        piece.locations = [0, NSNumber(value: Double(1 - tail / frame.width)), 1]
        piece.anchorPoint = CGPoint(x: 0, y: 0.5)
        piece.bounds = CGRect(origin: .zero, size: frame.size)
        piece.position = CGPoint(x: frame.minX, y: frame.midY)
        let grow = CABasicAnimation(keyPath: "bounds.size.width")
        grow.fromValue = 0
        grow.toValue = frame.width
        grow.beginTime = begin
        grow.duration = duration
        grow.fillMode = .backwards
        piece.add(grow, forKey: "reveal")

        return piece
    }
}
