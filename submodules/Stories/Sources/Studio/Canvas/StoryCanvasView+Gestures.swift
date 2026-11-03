import Haptics
import UIKit

extension StoryCanvasView {
    func bind(_ view: UIView, tappable: Bool) {
        var recognizers: [UIGestureRecognizer] = [
            UIPanGestureRecognizer(target: self, action: #selector(moved(_:))),
            UIPinchGestureRecognizer(target: self, action: #selector(scaled(_:))),
            UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:))),
        ]
        if tappable {
            recognizers.append(UITapGestureRecognizer(target: self, action: #selector(tappedItem(_:))))
        }
        for recognizer in recognizers {
            recognizer.delegate = self
            view.addGestureRecognizer(recognizer)
        }
    }

    private func index(of view: UIView?) -> Int? {
        guard let view, let id = itemIDs[ObjectIdentifier(view)] else {
            return nil
        }

        return entities.firstIndex { entity in
            entity.id == id
        }
    }

    @objc
    private func moved(_ gesture: UIPanGestureRecognizer) {
        guard let index = index(of: gesture.view) else {
            return
        }

        let shift = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        let center = dragRaw ?? entities[index].center
        let raw = CGPoint(
            x: center.x + shift.x / max(bounds.width, 1),
            y: center.y + shift.y / max(bounds.height, 1)
        )
        let isFinal = gesture.state == .ended || gesture.state == .cancelled
        dragRaw = isFinal ? nil : raw
        entities[index].center = gesture.view.map { view in
            snap(raw, for: view)
        } ?? raw
        place(entities[index])
        if let view = gesture.view, dragged(view, state: gesture.state, at: gesture.location(in: self)) {
            remove(at: index)
            Haptics.play(.success)

            return
        }

        finish(gesture)
    }

    @objc
    private func scaled(_ gesture: UIPinchGestureRecognizer) {
        guard let index = index(of: gesture.view) else {
            return
        }

        entities[index].scale = min(max(entities[index].scale * gesture.scale, 0.2), 8)
        gesture.scale = 1
        place(entities[index])
        finish(gesture)
    }

    @objc
    private func rotated(_ gesture: UIRotationGestureRecognizer) {
        guard let index = index(of: gesture.view) else {
            return
        }

        entities[index].rotation += gesture.rotation
        gesture.rotation = 0
        place(entities[index])
        finish(gesture)
    }

    @objc
    private func tappedItem(_ gesture: UITapGestureRecognizer) {
        guard let index = index(of: gesture.view) else {
            return
        }

        guard var widget = entities[index].widget else {
            onEditText?(entities[index].id)

            return
        }

        widget.style = widget.style.next
        entities[index].content = .widget(widget)
        place(entities[index])
        Haptics.play(.selection)
        changed()
    }

    private func finish(_ gesture: UIGestureRecognizer) {
        if gesture.state == .ended || gesture.state == .cancelled {
            changed()
        }
    }

    @objc
    func drew(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        guard brush != .eraser else {
            erase(at: point)
            if gesture.state == .ended || gesture.state == .cancelled {
                changed()
            }

            return
        }

        let normalized = CGPoint(x: point.x / max(bounds.width, 1), y: point.y / max(bounds.height, 1))
        switch gesture.state {
        case .began:
            let stroke = StoryStroke(
                points: [normalized],
                color: StoryColor(color),
                width: Self.lineWidth,
                brush: brush
            )
            let entity = StoryEntity(content: .drawing(stroke))
            entities.append(entity)
            makeView(for: entity)
            place(entity)
            drawingID = entity.id
        case .changed:
            guard let index = entities.firstIndex(where: { entity in
                entity.id == drawingID
            }), case .drawing(var stroke) = entities[index].content else {
                return
            }

            stroke.points.append(normalized)
            entities[index].content = .drawing(stroke)
            place(entities[index])
        default:
            drawingID = nil
            changed()
        }
    }

    private func erase(at point: CGPoint) {
        let reach = max(18, Self.lineWidth * bounds.width * 2)
        let hit = entities.lastIndex { entity in
            guard case .drawing(let stroke) = entity.content else {
                return false
            }

            return stroke.points.contains { normalized in
                hypot(normalized.x * bounds.width - point.x, normalized.y * bounds.height - point.y) < reach
            }
        }
        guard let hit else {
            return
        }

        let id = entities.remove(at: hit).id
        strokes.removeValue(forKey: id)?.removeFromSuperlayer()
        Haptics.play(.selection)
    }
}

extension StoryCanvasView {
    @discardableResult
    public func editText(
        _ id: UUID?,
        in host: UIView,
        color: UIColor,
        doneTitle: String,
        onFinish: @escaping @MainActor () -> Void
    ) -> StoryTextEditor {
        let current = id.flatMap(text(of:)) ?? StoryText(text: "", color: StoryColor(color))
        let editor = StoryTextEditor(text: current, doneTitle: doneTitle)
        if let id {
            setHidden(true, entity: id)
        }
        editor.onDone = { [weak self, weak editor] text in
            if let id {
                self?.setHidden(false, entity: id)
                self?.updateText(id, text: text)
            } else if !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self?.addText(text)
            }
            editor?.removeFromSuperview()
            onFinish()
        }
        editor.frame = host.bounds
        host.addSubview(editor)
        editor.begin()

        return editor
    }
}
