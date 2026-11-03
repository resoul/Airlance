import Metal
import QuartzCore
import UIKit

private struct LiquidLavaUniforms {
    var viewport: SIMD2<Float>
    var scale: Float
    var time: Float
    var tint: SIMD4<Float>
    var heat: Float
    var burst: Float
    var inner: Float
    var outer: Float
}

@MainActor
public final class LiquidLavaView: UIView {
    public var tint = UIColor(red: 0.85, green: 0.86, blue: 0.9, alpha: 1)
    public var heat: CGFloat = 0
    public var innerRadius: CGFloat = 40
    public var outerRadius: CGFloat = 80

    public var isAnimating = false {
        didSet {
            updateDriver()
        }
    }

    private static let maxFramesInFlight = 2
    private static let maxScale: CGFloat = 2

    private lazy var driver = DisplayLinkDriver(maximumRate: 60) { [weak self] deltaTime in
        self?.tick(deltaTime)
    }
    private var burst = Spring(0, stiffness: 9, dampingRatio: 0.55)
    private var burstTarget: CGFloat = 0
    private var shownHeat = Spring(0, stiffness: 8, dampingRatio: 1)
    private var time: CFTimeInterval = 0
    private var framesInFlight = 0

    public static var isSupported: Bool {
        LiquidGPU.shared?.lavaPipeline != nil
    }

    override public class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        time = Double.random(in: 0..<100)
        if let layer = layer as? CAMetalLayer, let gpu = LiquidGPU.shared {
            layer.device = gpu.device
            layer.pixelFormat = gpu.pixelFormat
            layer.isOpaque = false
            layer.framebufferOnly = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func burstOut() {
        burstTarget = 1
        updateDriver()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.burstTarget = 0
        }
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        updateDriver()
        render()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        render()
    }

    private func updateDriver() {
        if window != nil, isAnimating || burstTarget > 0 {
            driver.start()
        } else {
            driver.stop()
        }
    }

    private func tick(_ deltaTime: CFTimeInterval) {
        time += deltaTime * (1 + Double(shownHeat.value) * 1.5)
        burst.step(toward: burstTarget, deltaTime: deltaTime)
        shownHeat.step(toward: heat, deltaTime: deltaTime)
        if !isAnimating, burstTarget == 0, burst.isSettled(at: 0, tolerance: 0.002) {
            driver.stop()
        }
        render()
    }

    private func render() {
        guard
            window != nil,
            bounds.width > 0,
            bounds.height > 0,
            let gpu = LiquidGPU.shared,
            let pipeline = gpu.lavaPipeline,
            let layer = layer as? CAMetalLayer,
            framesInFlight < Self.maxFramesInFlight
        else {
            return
        }

        let scale = min(window?.screen.scale ?? 2, Self.maxScale)
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        if layer.drawableSize != size {
            layer.contentsScale = scale
            layer.drawableSize = size
        }
        guard let drawable = layer.nextDrawable(), let commandBuffer = gpu.queue.makeCommandBuffer() else {
            return
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: Self.pass(drawable.texture)) else {
            return
        }

        var uniforms = makeUniforms(size: size, scale: scale)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LiquidLavaUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        framesInFlight += 1
        commandBuffer.addCompletedHandler { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.framesInFlight -= 1
            }
        }
        commandBuffer.commit()
    }

    private static func pass(_ texture: any MTLTexture) -> MTLRenderPassDescriptor {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        return pass
    }

    private func makeUniforms(size: CGSize, scale: CGFloat) -> LiquidLavaUniforms {
        LiquidLavaUniforms(
            viewport: SIMD2(Float(size.width), Float(size.height)),
            scale: Float(scale),
            time: Float(time.truncatingRemainder(dividingBy: 10_000)),
            tint: Self.components(tint, traits: traitCollection),
            heat: Float(min(max(shownHeat.value, 0), 1)),
            burst: Float(max(burst.value, 0)),
            inner: Float(innerRadius),
            outer: Float(outerRadius)
        )
    }

    private static func components(_ color: UIColor, traits: UITraitCollection) -> SIMD4<Float> {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return SIMD4(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
