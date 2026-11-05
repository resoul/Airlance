@preconcurrency import AsyncDisplayKit
import ListUI
import MediaLoader
import UIKit

@MainActor
final class ChatRowThumbnailsNode: ASDisplayNode {
    private let images = (0..<ChatRowPreview.maxThumbnails).map { _ in
        ASImageNode()
    }
    private let plays = (0..<ChatRowPreview.maxThumbnails).map { _ in
        ASImageNode()
    }
    private var generation = 0

    override func didLoad() {
        super.didLoad()
        for (image, play) in zip(images, plays) {
            image.contentMode = .scaleAspectFill
            image.clipsToBounds = true
            image.cornerRadius = ChatRowLayout.thumbnailRadius
            image.backgroundColor = UIColor(white: 0.5, alpha: 0.25)
            image.isHidden = true
            play.isHidden = true
            play.contentMode = .center
            play.image = ListRowSymbols.image("play.fill", size: 8, color: .white)
            addSubnode(image)
            addSubnode(play)
        }
    }

    func clear() {
        generation += 1
        for (image, play) in zip(images, plays) {
            image.image = nil
            image.isHidden = true
            play.isHidden = true
        }
    }

    func show(_ thumbnails: [ChatRowThumbnail], frames: [CGRect], scale: CGFloat) {
        clear()
        let current = generation
        for (index, thumbnail) in thumbnails.prefix(frames.count).enumerated() {
            images[index].frame = frames[index]
            images[index].isHidden = false
            plays[index].frame = frames[index]
            plays[index].isHidden = !thumbnail.isVideo
            load(thumbnail, into: images[index], scale: scale, generation: current)
        }
    }

    private func load(_ thumbnail: ChatRowThumbnail, into node: ASImageNode, scale: CGFloat, generation current: Int) {
        let side = ChatRowLayout.thumbnailSide
        let request = MediaImageRequest(
            source: thumbnail.source,
            size: CGSize(width: side, height: side),
            scale: scale,
            corners: .uniform(ChatRowLayout.thumbnailRadius)
        )
        Task { [weak self, weak node] in
            await thumbnail.fetch?()
            let image = await MediaImageLoader.shared.image(for: request)
            guard let self, self.generation == current else {
                return
            }

            node?.image = image
        }
    }
}

@MainActor
final class ChatRowTypingNode: ASDisplayNode {
    private static let count = 3
    private static let size: CGFloat = 4
    private static let spacing: CGFloat = 3
    private static let period: CFTimeInterval = 1.2
    private let dots = (0..<3).map { _ in
        CALayer()
    }

    nonisolated static let width: CGFloat = 18

    override func didLoad() {
        super.didLoad()
        for (index, dot) in dots.enumerated() {
            let x = CGFloat(index) * (Self.size + Self.spacing)
            dot.frame = CGRect(x: x, y: 0, width: Self.size, height: Self.size)
            dot.cornerRadius = Self.size / 2
            layer.addSublayer(dot)
        }
    }

    func apply(color: UIColor) {
        for dot in dots {
            dot.backgroundColor = color.cgColor
        }
    }

    func setAnimating(_ isAnimating: Bool) {
        for (index, dot) in dots.enumerated() {
            dot.removeAnimation(forKey: "typing")
            guard isAnimating else {
                continue
            }

            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = [0.25, 1, 0.25]
            animation.keyTimes = [0, 0.5, 1]
            animation.duration = Self.period
            animation.repeatCount = .infinity
            animation.beginTime = CACurrentMediaTime() + Double(index) * Self.period / Double(Self.count)
            animation.isRemovedOnCompletion = false
            dot.add(animation, forKey: "typing")
        }
    }
}
