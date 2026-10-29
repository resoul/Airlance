import Metal
import QuartzCore
import UIKit

private struct LiquidWaveUniforms {
    var viewport: SIMD2<Float>
    var scale: Float
    var progress: Float
    var played: SIMD4<Float>
    var rest: SIMD4<Float>
    var time: Float
    var playing: Float
    var count: Float
    var unused: Float = 0
}

@MainActor
public final class LiquidWaveView: UIView {
    public var playedColor = UIColor.systemBlue
    public var restColor = UIColor.systemBlue.withAlphaComponent(0.35)
    public var amplitudes: [Float] = [] {
        didSet {
            render()
        }
    }

    public var progress: CGFloat = 0 {
        didSet {
            render()
        }
    }

    public var isPlaying = false {
        didSet {
            driver.start()
        }
    }

    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.tick(deltaTime)
    }
    private var playing = Spring(0, stiffness: 10, dampingRatio: 1)
    private var time: CFTimeInterval = 0

    public static var isSupported: Bool {
        LiquidGPU.shared?.wavePipeline != nil
    }

    override public class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
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

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            driver.stop()
        } else {
            render()
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        render()
    }

    private func tick(_ deltaTime: CFTimeInterval) {
        time += deltaTime
        playing.step(toward: isPlaying ? 1 : 0, deltaTime: deltaTime)
        if !isPlaying, playing.isSettled(at: 0, tolerance: 0.002) {
            playing.reset(to: 0)
            driver.stop()
        }
        render()
    }

    private func render() {
        guard
            window != nil,
            !amplitudes.isEmpty,
            bounds.width > 0,
            bounds.height > 0,
            let gpu = LiquidGPU.shared,
            let pipeline = gpu.wavePipeline,
            let layer = layer as? CAMetalLayer
        else {
            return
        }

        let scale = window?.screen.scale ?? 2
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        if layer.drawableSize != size {
            layer.contentsScale = scale
            layer.drawableSize = size
        }
        guard let drawable = layer.nextDrawable(), let commandBuffer = gpu.queue.makeCommandBuffer() else {
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

        encode(into: encoder, pipeline: pipeline, size: size, scale: scale)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func encode(
        into encoder: any MTLRenderCommandEncoder,
        pipeline: any MTLRenderPipelineState,
        size: CGSize,
        scale: CGFloat
    ) {
        var uniforms = LiquidWaveUniforms(
            viewport: SIMD2(Float(size.width), Float(size.height)),
            scale: Float(scale),
            progress: Float(min(max(progress, 0), 1)),
            played: Self.components(playedColor, traits: traitCollection),
            rest: Self.components(restColor, traits: traitCollection),
            time: Float(time),
            playing: Float(min(max(playing.value, 0), 1)),
            count: Float(amplitudes.count)
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LiquidWaveUniforms>.stride, index: 0)
        encoder.setFragmentBytes(amplitudes, length: MemoryLayout<Float>.stride * amplitudes.count, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
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
