import UIKit

final class StoryWidgetLayer: UIView {
    private var entities: [StoryEntity] = []
    private var views: [UUID: StoryWidgetView] = [:]
    private var aspect: CGSize?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ entities: [StoryEntity], aspect: CGSize?, votes: [UUID: Int]) {
        for view in views.values {
            view.removeFromSuperview()
        }
        views = [:]
        self.entities = entities
        self.aspect = aspect
        for entity in entities {
            guard let widget = entity.widget else {
                continue
            }

            let view = StoryWidgetView(widget: widget)
            view.vote = votes[entity.id]
            addSubview(view)
            views[entity.id] = view
        }
        setNeedsLayout()
    }

    func widget(at point: CGPoint) -> (StoryEntity, StoryWidgetView)? {
        for entity in entities.reversed() {
            guard let view = views[entity.id] else {
                continue
            }

            if view.bounds.insetBy(dx: -8, dy: -8).contains(view.convert(point, from: self)) {
                return (entity, view)
            }
        }

        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let content = contentRect
        for entity in entities {
            guard let view = views[entity.id] else {
                continue
            }

            view.transform = .identity
            view.layout(width: content.width)
            view.center = CGPoint(
                x: content.minX + entity.center.x * content.width,
                y: content.minY + entity.center.y * content.height
            )
            view.transform = CGAffineTransform(rotationAngle: entity.rotation)
                .scaledBy(x: entity.scale, y: entity.scale)
        }
    }

    private var contentRect: CGRect {
        guard let aspect, aspect.width > 0, aspect.height > 0 else {
            return bounds
        }

        let scale = max(bounds.width / aspect.width, bounds.height / aspect.height)
        let size = CGSize(width: aspect.width * scale, height: aspect.height * scale)

        let origin = CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)

        return CGRect(origin: origin, size: size)
    }
}
