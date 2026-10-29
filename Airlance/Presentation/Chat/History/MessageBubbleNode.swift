@preconcurrency import AsyncDisplayKit
import ChatHistory
import LiquidUI
import ListUI
import UIKit

final class MessageBubbleNode: ListItemNode {
    private let shape = CAShapeLayer()
    private let flashLayer = CALayer()
    private var layoutResult: MessageBubbleLayout?
    private var morphFrom: MessageBubbleLayout?
    private weak var fading: ASDisplayNode?
    var waveView: LiquidWaveView?
    var downloadRing: CAShapeLayer?

    var voiceLayout: (parts: VoiceParts, origin: CGPoint)? {
        layoutResult.flatMap { layout in
            layout.voice.map { parts in
                (parts, layout.bubbleFrame.origin)
            }
        }
    }
    private var color = UIColor.clear
    private var imageTasks: [Task<Void, Never>] = []

    override func didLoad() {
        super.didLoad()
        layer.insertSublayer(shape, at: 0)
        flashLayer.opacity = 0
        layer.insertSublayer(flashLayer, at: 0)
    }

    var bubbleFrame: CGRect? {
        layoutResult.map { layout in
            layout.bubbleFrame.insetBy(dx: -MessageBubbleLayout.tailWidth, dy: 0)
        }
    }

    var tiles: [MediaTile] {
        layoutResult?.tiles ?? []
    }

    func tileIndex(at point: CGPoint) -> Int? {
        guard let layout = layoutResult else {
            return nil
        }

        let local = CGPoint(x: point.x - layout.bubbleFrame.minX, y: point.y - layout.bubbleFrame.minY)

        return layout.tiles.firstIndex { tile in
            tile.node.frame.contains(local)
        }
    }

    var fileIconFrame: CGRect? {
        layoutResult.flatMap { layout in
            layout.fileIcon.map { icon in
                icon.offsetBy(dx: layout.bubbleFrame.minX, dy: layout.bubbleFrame.minY)
            }
        }
    }

    var isOutgoing: Bool {
        layoutResult?.isOutgoing ?? false
    }

    func action(at point: CGPoint) -> BubbleAction.Kind? {
        guard let layout = layoutResult else {
            return nil
        }

        let local = CGPoint(x: point.x - layout.bubbleFrame.minX, y: point.y - layout.bubbleFrame.minY)
        if let text = layout.linkText, text.frame.contains(local) {
            let inText = CGPoint(x: local.x - text.frame.minX, y: local.y - text.frame.minY)
            if let url = text.linkAttributeValue(at: inText, attributeName: nil, range: nil) as? URL {
                return .url(url)
            }
        }

        return layout.actions.first { action in
            action.frame.contains(local)
        }?.kind
    }

    func flash(color: UIColor) {
        flashLayer.frame = bounds
        flashLayer.backgroundColor = color.resolvedColor(with: view.traitCollection).cgColor
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [0, 1, 1, 0]
        animation.keyTimes = [0, 0.15, 0.6, 1]
        animation.duration = 1.2
        flashLayer.add(animation, forKey: "flash")
    }

    func apply(_ layout: MessageBubbleLayout, color: UIColor) {
        let previous = layoutResult
        if previous?.messageID != layout.messageID || layout.voice == nil {
            removeVoice()
        }
        if previous?.messageID != layout.messageID || layout.fileIcon == nil {
            removeDownload()
        }
        if let previous, previous.content.supernode === self, previous.content !== layout.content {
            if Self.morphs(from: previous, to: layout) {
                morphFrom = previous
                fadeOut(previous.content)
            } else {
                previous.content.removeFromSupernode()
            }
        }
        layoutResult = layout
        self.color = color
        layout.content.frame.origin = layout.bubbleFrame.origin
        if layout.content.supernode !== self {
            addSubnode(layout.content)
        }
        loadImages(layout)
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        guard let layoutResult else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.frame = CGRect(origin: .zero, size: bounds.size)
        shape.fillColor = color.resolvedColor(with: view.traitCollection).cgColor
        shape.path = Self.path(layoutResult)
        CATransaction.commit()
        if let morphFrom {
            self.morphFrom = nil
            morph(from: morphFrom, to: layoutResult)
        }
    }

    private static func path(_ layout: MessageBubbleLayout) -> CGPath {
        let frame = layout.bubbleFrame
        let path = BubblePath.make(size: frame.size, outgoing: layout.isOutgoing, grouping: layout.grouping)
        var transform = CGAffineTransform(translationX: frame.minX, y: frame.minY)

        return path.copy(using: &transform) ?? path
    }

    private static func morphs(from previous: MessageBubbleLayout, to next: MessageBubbleLayout) -> Bool {
        previous.messageID == next.messageID
            && previous.width == next.width
            && previous.bubbleFrame.size != next.bubbleFrame.size
            && !UIAccessibility.isReduceMotionEnabled
    }

    private func morph(from previous: MessageBubbleLayout, to next: MessageBubbleLayout) {
        let spring = CASpringAnimation(keyPath: "path")
        spring.fromValue = Self.path(previous)
        spring.toValue = Self.path(next)
        spring.stiffness = 380
        spring.damping = 35
        spring.duration = spring.settlingDuration
        shape.add(spring, forKey: "morph")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.25
        fade.beginTime = CACurrentMediaTime() + 0.08
        fade.fillMode = .backwards
        next.content.layer.add(fade, forKey: "fade")
    }

    private func fadeOut(_ content: ASDisplayNode) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.18
        content.layer.opacity = 0
        content.layer.add(fade, forKey: "fade")
        fading = content
        Task { [weak self, weak content] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self, let content, content.supernode === self, content !== self.layoutResult?.content else {
                return
            }

            content.removeFromSupernode()
            content.layer.opacity = 1
        }
    }

    private func loadImages(_ layout: MessageBubbleLayout) {
        cancelImages()
        let loader = MediaImageLoader.shared
        for tile in layout.tiles + layout.images where tile.node.image == nil {
            if let image = loader.cached(tile.request) {
                Self.show(image, in: tile)
                continue
            }

            imageTasks.append(
                Task { [weak self] in
                    let image = await loader.image(for: tile.request)
                    guard let image, let self, self.layoutResult === layout else {
                        return
                    }

                    Self.show(image, in: tile)
                }
            )
        }
    }

    private func cancelImages() {
        for task in imageTasks {
            task.cancel()
        }
        imageTasks = []
    }

    private static func show(_ image: UIImage, in tile: MediaTile) {
        tile.node.image = image
        tile.node.backgroundColor = .clear
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        for content in [layoutResult?.content, fading] {
            if let content, content.supernode === self {
                content.removeFromSupernode()
                content.layer.opacity = 1
            }
        }
        layoutResult = nil
        morphFrom = nil
        removeVoice()
        shape.path = nil
        cancelImages()
    }
}

enum BubblePath {
    static func make(size: CGSize, outgoing: Bool, grouping: HistoryGrouping) -> CGPath {
        let width = size.width
        let height = size.height
        let big = min(17, height / 2)
        let small: CGFloat = 6
        let topRight = grouping.joinedTop ? small : big
        let bottomRight = grouping.joinedBottom ? small : big
        let path = UIBezierPath()
        path.move(to: CGPoint(x: big, y: 0))
        path.addLine(to: CGPoint(x: width - topRight, y: 0))
        path.addArc(
            withCenter: CGPoint(x: width - topRight, y: topRight),
            radius: topRight,
            startAngle: -.pi / 2,
            endAngle: 0,
            clockwise: true
        )
        if grouping.joinedBottom {
            path.addLine(to: CGPoint(x: width, y: height - bottomRight))
            let corner = CGPoint(x: width, y: height)
            path.addQuadCurve(to: CGPoint(x: width - bottomRight, y: height), controlPoint: corner)
        } else {
            path.addLine(to: CGPoint(x: width, y: height - 11))
            path.addQuadCurve(to: CGPoint(x: width + 6, y: height), controlPoint: CGPoint(x: width, y: height - 1))
        }
        path.addLine(to: CGPoint(x: big, y: height))
        let bottomLeft = CGPoint(x: big, y: height - big)
        path.addArc(withCenter: bottomLeft, radius: big, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: big))
        let topLeft = CGPoint(x: big, y: big)
        path.addArc(withCenter: topLeft, radius: big, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        path.close()
        if !outgoing {
            path.apply(CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -width, y: 0))
        }

        return path.cgPath
    }
}
