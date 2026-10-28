import Haptics
import Metal
import QuartzCore
import UIKit

@MainActor
public final class LiquidThemeReveal {
    private weak var view: ThemeRevealView?

    private init(view: ThemeRevealView?) {
        self.view = view
    }

    public static func cover(_ window: UIWindow, from point: CGPoint) -> LiquidThemeReveal {
        let scale = window.traitCollection.displayScale
        guard let gpu = LiquidGPU.shared, gpu.revealPipeline != nil,
              let snapshot = gpu.makeTexture(snapshotting: window, scale: scale) else {
            return LiquidThemeReveal(view: nil)
        }

        let view = ThemeRevealView(snapshot: snapshot, origin: point, frame: window.bounds, scale: scale)
        window.addSubview(view)
        view.render()

        return LiquidThemeReveal(view: view)
    }

    public func reveal() {
        view?.start()
    }
}

private struct ThemeRevealUniforms {
    var viewport: SIMD2<Float>
    var scale: Float
    var radius: Float
    var origin: SIMD2<Float>
    var time: Float
    var seed: Float
}

@MainActor
private final class ThemeRevealView: UIView {
    private static let duration: CFTimeInterval = 0.95

    private let snapshot: any MTLTexture
    private let origin: CGPoint
    private let seed = Float.random(in: 0...40)
    private var started: CFTimeInterval?
    private lazy var driver = DisplayLinkDriver { [weak self] _ in
        self?.tick()
    }

    override class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    init(snapshot: any MTLTexture, origin: CGPoint, frame: CGRect, scale: CGFloat) {
        self.snapshot = snapshot
        self.origin = origin
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentScaleFactor = scale
        if let layer = layer as? CAMetalLayer {
            layer.device = LiquidGPU.shared?.device
            layer.pixelFormat = LiquidGPU.shared?.pixelFormat ?? .bgra8Unorm
            layer.isOpaque = false
            layer.framebufferOnly = true
            layer.contentsScale = scale
            layer.drawableSize = CGSize(width: frame.width * scale, height: frame.height * scale)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func start() {
        guard started == nil else {
            return
        }

        started = CACurrentMediaTime()
        superview?.bringSubviewToFront(self)
        Haptics.play(.reveal)
        driver.start()
    }

    private var elapsed: CFTimeInterval {
        started.map { start in
            CACurrentMediaTime() - start
        } ?? 0
    }

    private var maxRadius: CGFloat {
        let corners = [
            CGPoint.zero,
            CGPoint(x: bounds.width, y: 0),
            CGPoint(x: 0, y: bounds.height),
            CGPoint(x: bounds.width, y: bounds.height),
        ]
        let distances = corners.map { corner in
            hypot(corner.x - origin.x, corner.y - origin.y)
        }
        let farthest = distances.max() ?? 0

        return farthest + 90
    }

    private func tick() {
        render()
        if elapsed >= Self.duration {
            driver.stop()
            removeFromSuperview()
        }
    }

    func render() {
        guard let gpu = LiquidGPU.shared, let pipeline = gpu.revealPipeline,
              let layer = layer as? CAMetalLayer, let drawable = layer.nextDrawable(),
              let commandBuffer = gpu.queue.makeCommandBuffer() else {
            return
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }

        let progress = min(1, elapsed / Self.duration)
        let eased = progress * progress * (3 - 2 * progress)
        var uniforms = ThemeRevealUniforms(
            viewport: SIMD2(Float(drawable.texture.width), Float(drawable.texture.height)),
            scale: Float(contentScaleFactor),
            radius: Float(CGFloat(eased) * maxRadius),
            origin: SIMD2(Float(origin.x), Float(origin.y)),
            time: Float(elapsed),
            seed: seed
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(snapshot, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ThemeRevealUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
