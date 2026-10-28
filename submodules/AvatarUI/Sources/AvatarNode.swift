@preconcurrency import AsyncDisplayKit
import UIKit

@MainActor
public final class AvatarNode: ASDisplayNode {
    private static let pixelSteps = [64, 96, 128, 192, 256, 384, 512, 1024]

    public private(set) var storyRing: AvatarStoryRing?
    public var isOnScreen = true {
        didSet {
            if isOnScreen != oldValue {
                AvatarPlayback.shared.update()
            }
        }
    }
    public var contentCornerRadius: CGFloat? {
        didSet {
            if (contentCornerRadius == nil) != (oldValue == nil) {
                reset()
            }
            setNeedsLayout()
        }
    }

    let imageNode = ASImageNode()
    var videoNode: AvatarVideoNode?
    var descriptor: AvatarDescriptor?
    var presentation: AvatarPresentation = .list
    var isPlaybackAllowed = false
    private var ringNode: StoryRingNode?
    private var renderedPixels = 0
    private var hasPhoto = false
    private var task: Task<Void, Never>?

    var contentFrame: CGRect {
        let inset = storyRing?.contentInset ?? 0

        return bounds.insetBy(dx: inset, dy: inset)
    }

    override public func didLoad() {
        super.didLoad()
        imageNode.isLayerBacked = true
        imageNode.contentMode = .scaleToFill
        imageNode.displaysAsynchronously = false
        addSubnode(imageNode)
    }

    public func apply(_ descriptor: AvatarDescriptor, presentation: AvatarPresentation = .list) {
        guard descriptor != self.descriptor || presentation != self.presentation else {
            return
        }

        let videoChanged = descriptor.video != self.descriptor?.video || presentation != self.presentation
        self.presentation = presentation
        if descriptor.id != self.descriptor?.id || descriptor.image != self.descriptor?.image {
            self.descriptor = descriptor
            reset()
        } else {
            self.descriptor = descriptor
        }
        if videoChanged {
            resetVideo()
        }
        AvatarPlayback.shared.register(self)
        AvatarPlayback.shared.update()
        setNeedsLayout()
    }

    public func setStoryRing(_ ring: AvatarStoryRing?) {
        guard ring != storyRing else {
            return
        }

        let insetChanged = ring?.contentInset != storyRing?.contentInset
        storyRing = ring
        if let ring {
            let node = ringNode ?? StoryRingNode()
            if ringNode == nil {
                ringNode = node
                addSubnode(node)
            }
            node.update(ring)
        } else {
            ringNode?.removeFromSupernode()
            ringNode = nil
        }
        if insetChanged {
            renderedPixels = 0
        }
        setNeedsLayout()
    }

    public func prepareForReuse() {
        descriptor = nil
        reset()
        resetVideo()
        setStoryRing(nil)
        AvatarPlayback.shared.unregister(self)
    }

    override public func didEnterHierarchy() {
        super.didEnterHierarchy()
        AvatarPlayback.shared.update()
    }

    override public func didExitHierarchy() {
        super.didExitHierarchy()
        AvatarPlayback.shared.update()
        videoNode?.reset()
    }

    override public func layout() {
        super.layout()
        let content = contentFrame
        let radius = contentCornerRadius ?? min(content.width, content.height) / 2
        imageNode.frame = content
        imageNode.cornerRadius = radius
        imageNode.clipsToBounds = !isRounded
        imageNode.contentMode = isRounded ? .scaleToFill : .scaleAspectFill
        imageNode.backgroundColor = imageNode.image == nil ? descriptor?.colors.last : nil
        videoNode?.frame = content
        videoNode?.contentCornerRadius = radius
        ringNode?.frame = bounds
        render()
    }

    private var isRounded: Bool {
        contentCornerRadius == nil
    }

    private func reset() {
        task?.cancel()
        task = nil
        renderedPixels = 0
        hasPhoto = false
        imageNode.image = nil
    }

    private func render() {
        let content = contentFrame
        guard let descriptor, content.width > 0 else {
            return
        }

        let target = Int((max(content.width, content.height) * view.traitCollection.displayScale).rounded(.up))
        let pixels = Self.pixelSteps.first { step in
            step >= target
        } ?? Self.pixelSteps[Self.pixelSteps.count - 1]
        guard pixels > renderedPixels else {
            return
        }

        renderedPixels = pixels
        if let image = descriptor.image, let cached = AvatarImageLoader.shared.cached(
            AvatarImageLoader.photoKey(image, pixelSize: pixels, rounded: isRounded)
        ) {
            hasPhoto = true
            show(cached)

            return
        }

        if !hasPhoto, let cached = AvatarImageLoader.shared.cached(
            AvatarImageLoader.placeholderKey(descriptor, pixelSize: pixels, rounded: isRounded)
        ) {
            show(cached)
        }

        task?.cancel()
        task = Task { [weak self] in
            await self?.load(descriptor, pixels: pixels)
        }
    }

    private func load(_ descriptor: AvatarDescriptor, pixels: Int) async {
        let loader = AvatarImageLoader.shared
        let rounded = isRounded
        if imageNode.image == nil {
            let placeholder = await loader.placeholder(for: descriptor, pixelSize: pixels, rounded: rounded)
            guard !Task.isCancelled, self.descriptor == descriptor, !hasPhoto else {
                return
            }

            show(placeholder)
        }

        guard let image = descriptor.image, let photo = await loader.photo(
            image,
            pixelSize: pixels,
            rounded: rounded
        ) else {
            return
        }

        guard !Task.isCancelled, self.descriptor?.image == image, isRounded == rounded else {
            return
        }

        hasPhoto = true
        show(photo)
    }

    private func show(_ image: UIImage) {
        imageNode.image = image
        imageNode.backgroundColor = nil
    }
}
