import UIKit

public final class SubtitleView: UIView {
    public var subtitles: Subtitles? {
        didSet {
            render()
        }
    }

    private let plate = UIView()
    private let label = UILabel()
    private var time: TimeInterval = 0
    private var shown: (id: UUID, word: Int?)?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        label.numberOfLines = 0
        plate.layer.cornerRadius = 10
        plate.addSubview(label)
        addSubview(plate)
        plate.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)

        return hit === self ? nil : hit
    }

    public func update(time: TimeInterval) {
        self.time = time
        let active = subtitles?.active(at: time)
        guard active?.phrase.id != shown?.id || active?.word != shown?.word else {
            return
        }

        render()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        render()
    }

    private func render() {
        guard let subtitles, subtitles.isShown, let active = subtitles.active(at: time), bounds.width > 0 else {
            plate.isHidden = true
            shown = nil

            return
        }

        shown = (active.phrase.id, active.word)
        let text = SubtitleText.attributed(
            active.phrase,
            highlight: active.word,
            style: subtitles.style,
            width: bounds.width
        )
        let frame = SubtitleText.frame(for: text, position: subtitles.position, in: bounds.size)
        plate.isHidden = false
        plate.frame = frame
        plate.backgroundColor = SubtitleText.plateColor(subtitles.style)
        label.attributedText = text
        label.frame = plate.bounds
    }

    @objc
    private func dragged(_ gesture: UIPanGestureRecognizer) {
        guard var subtitles, bounds.height > 0 else {
            return
        }

        let shift = gesture.translation(in: self).y / bounds.height
        gesture.setTranslation(.zero, in: self)
        subtitles.position = min(max(subtitles.position + shift, 0.12), 0.88)
        self.subtitles = subtitles
    }
}
