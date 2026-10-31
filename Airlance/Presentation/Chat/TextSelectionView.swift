import Haptics
import UIKit

final class TextSelectionView: UIView {
    private static let margin: CGFloat = 14
    private static let knobReach: CGFloat = 26

    var onChange: (@MainActor (NSRange?) -> Void)?

    private(set) var selection: NSRange?

    private let source: SelectableText
    private let storage: NSTextStorage
    private let manager = NSLayoutManager()
    private let container: NSTextContainer
    private let fill = CAShapeLayer()
    private let startKnob = TextSelectionKnob(isStart: true)
    private let endKnob = TextSelectionKnob(isStart: false)
    private var anchor: Int?

    init(source: SelectableText, color: UIColor) {
        self.source = source
        storage = NSTextStorage(attributedString: source.attributed)
        container = NSTextContainer(size: CGSize(width: source.frame.width, height: .greatestFiniteMagnitude))
        super.init(frame: source.frame.insetBy(dx: -Self.margin, dy: -Self.margin))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byWordWrapping
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        fill.fillColor = color.withAlphaComponent(0.3).cgColor
        layer.addSublayer(fill)
        for knob in [startKnob, endKnob] {
            knob.color = color
            knob.isHidden = true
            layer.addSublayer(knob)
        }
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var selectedText: String? {
        selection.map { range in
            (source.text as NSString).substring(with: range)
        }
    }

    func clear() {
        setSelection(nil)
    }

    private var length: Int {
        storage.length
    }

    private func textPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - Self.margin, y: point.y - Self.margin)
    }

    private func isOnText(_ point: CGPoint) -> Bool {
        let used = manager.usedRect(for: container).insetBy(dx: -4, dy: -4)

        return used.contains(textPoint(point))
    }

    private func index(at point: CGPoint) -> Int {
        var fraction: CGFloat = 0
        let index = manager.characterIndex(
            for: textPoint(point),
            in: container,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )

        return min(length, index + (fraction > 0.5 ? 1 : 0))
    }

    private func wordRange(at point: CGPoint) -> NSRange? {
        let position = manager.characterIndex(
            for: textPoint(point),
            in: container,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        let string = storage.string as NSString
        var found: NSRange?
        string.enumerateSubstrings(in: NSRange(location: 0, length: length), options: .byWords) { _, range, _, stop in
            if NSLocationInRange(position, range) {
                found = range
                stop.pointee = true
            }
        }

        return found
    }

    private func setSelection(_ range: NSRange?) {
        let next = range.flatMap { range in
            range.length > 0 ? range : nil
        }
        guard next != selection else {
            return
        }

        if next != nil {
            Haptics.play(.selection)
        }
        selection = next
        redraw()
        onChange?(next)
    }

    private func redraw() {
        guard let selection else {
            fill.path = nil
            startKnob.isHidden = true
            endKnob.isHidden = true

            return
        }

        let rects = lineRects(selection)
        let path = UIBezierPath()
        for rect in rects {
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: 3))
        }
        fill.path = path.cgPath
        if let first = rects.first, let last = rects.last {
            startKnob.place(top: first.minY, bottom: first.maxY, x: first.minX)
            endKnob.place(top: last.minY, bottom: last.maxY, x: last.maxX)
        }
        startKnob.isHidden = false
        endKnob.isHidden = false
    }

    private func lineRects(_ range: NSRange) -> [CGRect] {
        let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rects: [CGRect] = []
        manager.enumerateEnclosingRects(
            forGlyphRange: glyphs,
            withinSelectedGlyphRange: glyphs,
            in: container
        ) { rect, _ in
            rects.append(rect.offsetBy(dx: Self.margin, dy: Self.margin))
        }

        return rects
    }

    @objc
    private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        guard isOnText(point), selection == nil || !(selectionContains(point)) else {
            setSelection(nil)

            return
        }

        setSelection(wordRange(at: point))
    }

    private func selectionContains(_ point: CGPoint) -> Bool {
        guard let selection else {
            return false
        }

        return lineRects(selection).contains { rect in
            rect.contains(point)
        }
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            beginDrag(at: point)
        case .changed:
            guard let anchor else {
                return
            }

            let position = index(at: point)
            let lower = min(anchor, position)
            setSelection(NSRange(location: lower, length: max(anchor, position) - lower))
        default:
            anchor = nil
        }
    }

    private func beginDrag(at point: CGPoint) {
        Haptics.prepare(.selection)
        if let selection, startKnob.reaches(point, within: Self.knobReach) {
            anchor = NSMaxRange(selection)
        } else if let selection, endKnob.reaches(point, within: Self.knobReach) {
            anchor = selection.location
        } else {
            anchor = index(at: point)
        }
    }
}

extension TextSelectionView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        let point = gesture.location(in: self)
        let onKnob = startKnob.reaches(point, within: Self.knobReach) || endKnob.reaches(point, within: Self.knobReach)

        return (selection != nil && onKnob) || isOnText(point)
    }
}

final class TextSelectionKnob: CALayer {
    private let bar = CALayer()
    private let dot = CALayer()
    private let isStart: Bool

    var color: UIColor = .systemBlue {
        didSet {
            bar.backgroundColor = color.cgColor
            dot.backgroundColor = color.cgColor
        }
    }

    init(isStart: Bool) {
        self.isStart = isStart
        super.init()
        addSublayer(bar)
        addSublayer(dot)
    }

    override init(layer: Any) {
        isStart = (layer as? TextSelectionKnob)?.isStart ?? true
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func place(top: CGFloat, bottom: CGFloat, x: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let size: CGFloat = 10
        frame = CGRect(x: x - size / 2, y: top - size, width: size, height: bottom - top + size * 2)
        bar.frame = CGRect(x: size / 2 - 1, y: size, width: 2, height: bottom - top)
        let dotY = isStart ? 0 : bottom - top + size
        dot.frame = CGRect(x: 0, y: dotY, width: size, height: size)
        dot.cornerRadius = size / 2
        CATransaction.commit()
    }

    func reaches(_ point: CGPoint, within distance: CGFloat) -> Bool {
        !isHidden && frame.insetBy(dx: -distance, dy: -distance / 2).contains(point)
    }
}
