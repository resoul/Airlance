import Haptics
import UIKit

public final class StoryCanvasView: UIView, UIGestureRecognizerDelegate {
    public static let lineWidth: CGFloat = 0.018

    public var onEditText: (@MainActor (UUID) -> Void)?
    public var onChange: (@MainActor ([StoryEntity]) -> Void)?
    public var onDragging: (@MainActor (Bool) -> Void)?
    public var color = UIColor.white
    public var brush = StoryBrush.pen

    public var isDrawing = false {
        didSet {
            drawPan.isEnabled = isDrawing
            for view in items.values {
                view.isUserInteractionEnabled = !isDrawing
            }
        }
    }

    public internal(set) var entities: [StoryEntity] = []
    var items: [UUID: UIView] = [:]
    var itemIDs: [ObjectIdentifier: UUID] = [:]
    var strokes: [UUID: CAShapeLayer] = [:]
    var drawingID: UUID?
    let strokesLayer = CALayer()
    let trash = UIImageView()
    let guidesLayer = CAShapeLayer()
    let activeGuidesLayer = CAShapeLayer()
    var activeGuides: Set<Guide> = []
    var dragRaw: CGPoint?
    lazy var drawPan = UIPanGestureRecognizer(target: self, action: #selector(drew(_:)))

    override public init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(strokesLayer)
        drawPan.maximumNumberOfTouches = 1
        drawPan.isEnabled = false
        addGestureRecognizer(drawPan)
        setUpTrash()
        setUpGuides()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public var isEmpty: Bool {
        entities.isEmpty
    }

    public var canUndo: Bool {
        entities.contains(where: \.isDrawing)
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)

        return hit === self && !isDrawing ? nil : hit
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        strokesLayer.frame = bounds
        trash.center = CGPoint(x: bounds.midX, y: bounds.height - max(safeAreaInsets.bottom, 16) - 60)
        for entity in entities {
            place(entity)
        }
    }

    public func load(_ entities: [StoryEntity]) {
        items.values.forEach { view in
            view.removeFromSuperview()
        }
        strokes.values.forEach { stroke in
            stroke.removeFromSuperlayer()
        }
        items = [:]
        itemIDs = [:]
        strokes = [:]
        self.entities = entities
        for entity in entities {
            makeView(for: entity)
        }
        setNeedsLayout()
    }

    public func text(of id: UUID) -> StoryText? {
        guard let entity = entities.first(where: { entity in
            entity.id == id
        }), case .text(let text) = entity.content else {
            return nil
        }

        return text
    }

    public func setHidden(_ isHidden: Bool, entity id: UUID) {
        items[id]?.isHidden = isHidden
    }

    public func addText(_ text: StoryText) {
        add(StoryEntity(content: .text(text)))
    }

    public func addSticker(_ sticker: StorySticker) {
        add(StoryEntity(content: .sticker(sticker), center: CGPoint(x: 0.5, y: 0.42)))
        Haptics.play(.tap)
    }

    public func addWidget(_ widget: StoryWidget, center: CGPoint = CGPoint(x: 0.5, y: 0.42)) {
        add(StoryEntity(content: .widget(widget), center: center))
        Haptics.play(.tap)
    }

    public func updateText(_ id: UUID, text: StoryText) {
        guard let index = entities.firstIndex(where: { entity in
            entity.id == id
        }) else {
            return
        }

        guard !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            remove(at: index)

            return
        }

        entities[index].content = .text(text)
        place(entities[index])
        changed()
    }

    public func undo() {
        guard let index = entities.lastIndex(where: \.isDrawing) else {
            return
        }

        remove(at: index)
        Haptics.play(.tap)
    }

    public func render(width: CGFloat) -> UIImage? {
        guard !isEmpty, bounds.width > 0 else {
            return nil
        }

        trash.isHidden = true
        setGuidesVisible(false)
        let format = UIGraphicsImageRendererFormat()
        format.scale = width / bounds.width
        format.opaque = false

        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            layer.render(in: context.cgContext)
        }
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer.view === otherGestureRecognizer.view
    }

    func changed() {
        onChange?(entities)
    }

    func add(_ entity: StoryEntity) {
        entities.append(entity)
        makeView(for: entity)
        place(entity)
        changed()
    }

    func remove(at index: Int) {
        let id = entities.remove(at: index).id
        if let view = items.removeValue(forKey: id) {
            itemIDs.removeValue(forKey: ObjectIdentifier(view))
            view.removeFromSuperview()
        }
        strokes.removeValue(forKey: id)?.removeFromSuperlayer()
        changed()
    }

    func makeView(for entity: StoryEntity) {
        switch entity.content {
        case .text:
            let label = UILabel()
            label.numberOfLines = 0
            label.textAlignment = .center
            register(label, id: entity.id, tappable: true)
        case .sticker(let sticker):
            register(Self.stickerView(sticker), id: entity.id, tappable: false)
        case .widget(let widget):
            register(StoryWidgetView(widget: widget), id: entity.id, tappable: true)
        case .drawing:
            let stroke = CAShapeLayer()
            stroke.fillColor = nil
            stroke.lineCap = .round
            stroke.lineJoin = .round
            strokesLayer.addSublayer(stroke)
            strokes[entity.id] = stroke
        }
    }

    private func register(_ view: UIView, id: UUID, tappable: Bool) {
        view.isUserInteractionEnabled = !isDrawing
        bind(view, tappable: tappable)
        insertSubview(view, belowSubview: trash)
        items[id] = view
        itemIDs[ObjectIdentifier(view)] = id
    }

    private static func stickerView(_ sticker: StorySticker) -> UIView {
        switch sticker.source {
        case .emoji(let emoji):
            let label = UILabel()
            label.text = emoji
            label.textAlignment = .center

            return label
        case .image(let url):
            let image = UIImageView(image: UIImage(contentsOfFile: url.path))
            image.contentMode = .scaleAspectFit

            return image
        }
    }

    func place(_ entity: StoryEntity) {
        guard bounds.width > 0 else {
            return
        }

        if case .drawing(let stroke) = entity.content, let layer = strokes[entity.id] {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            StoryLook.apply(stroke, to: layer, path: path(for: stroke), width: bounds.width)
            CATransaction.commit()

            return
        }

        guard let view = items[entity.id] else {
            return
        }

        view.transform = .identity
        switch entity.content {
        case .text(let text):
            if let label = view as? UILabel {
                StoryLook.apply(text, to: label, width: bounds.width)
            }
        case .sticker(let sticker):
            size(view, sticker: sticker)
        case .widget(let widget):
            if let view = view as? StoryWidgetView {
                view.update(widget)
                view.layout(width: bounds.width)
            }
        case .drawing:
            break
        }
        view.center = CGPoint(x: entity.center.x * bounds.width, y: entity.center.y * bounds.height)
        view.transform = CGAffineTransform(rotationAngle: entity.rotation).scaledBy(x: entity.scale, y: entity.scale)
    }

    private func size(_ view: UIView, sticker: StorySticker) {
        let width = sticker.width * bounds.width
        if let label = view as? UILabel {
            label.font = .systemFont(ofSize: width * 0.82)
            label.bounds = CGRect(x: 0, y: 0, width: width, height: width)
        } else if let image = (view as? UIImageView)?.image, image.size.width > 0 {
            view.bounds = CGRect(x: 0, y: 0, width: width, height: width * image.size.height / image.size.width)
        }
    }
}

extension StoryCanvasView {
    func path(for stroke: StoryStroke) -> UIBezierPath {
        let path = UIBezierPath()
        let points = stroke.points.map { point in
            CGPoint(x: point.x * bounds.width, y: point.y * bounds.height)
        }
        guard let first = points.first else {
            return path
        }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        if points.count == 1 {
            path.addLine(to: first)
        }

        return path
    }
}
