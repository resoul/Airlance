import Metal
import QuartzCore
import UIKit

@MainActor
public final class LiquidCanvasView: UIView {
    public var color = UIColor.systemBlue
    public var gloss: CGFloat = 0.4
    public var rimWidth: CGFloat = 6
    public var blobs: [LiquidBlob] = []
    public var bridges: [LiquidBridge] = []
    public var onFrame: (@MainActor (CFTimeInterval) -> Void)?

    private let gpu = LiquidGPU.shared
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.onFrame?(deltaTime)
        self?.render()
    }
    private var wantsFrames = false

    public static var isSupported: Bool {
        LiquidGPU.shared != nil
    }

    override public class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    private var metalLayer: CAMetalLayer? {
        layer as? CAMetalLayer
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        metalLayer?.device = gpu?.device
        metalLayer?.pixelFormat = gpu?.pixelFormat ?? .bgra8Unorm
        metalLayer?.isOpaque = false
        metalLayer?.framebufferOnly = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func startFrames() {
        wantsFrames = true
        updateDriver()
    }

    public func stopFrames() {
        wantsFrames = false
        updateDriver()
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            contentScaleFactor = window.screen.scale
        }
        updateDriver()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let size = CGSize(
            width: (bounds.width * contentScaleFactor).rounded(),
            height: (bounds.height * contentScaleFactor).rounded()
        )
        guard size.width > 0, size.height > 0, size != metalLayer?.drawableSize else {
            return
        }

        metalLayer?.contentsScale = contentScaleFactor
        metalLayer?.drawableSize = size
        render()
    }

    public func render() {
        guard
            let gpu,
            let metalLayer,
            metalLayer.drawableSize.width > 0,
            let drawable = metalLayer.nextDrawable(),
            let commandBuffer = gpu.queue.makeCommandBuffer()
        else {
            return
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) {
            encode(into: encoder, gpu: gpu)
            encoder.endEncoding()
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func encode(into encoder: any MTLRenderCommandEncoder, gpu: LiquidGPU) {
        let extent = (blobs.map(\.extent) + bridges.map(\.extent)).reduce(CGRect.null) { result, rect in
            result.union(rect)
        }
        guard !extent.isNull else {
            return
        }

        var uniforms = LiquidUniforms(
            scale: Float(contentScaleFactor),
            gloss: Float(gloss),
            rimWidth: Float(rimWidth),
            color: color.liquidComponents(with: traitCollection),
            bounds: SIMD4(Float(extent.minX), Float(extent.minY), Float(extent.maxX), Float(extent.maxY)),
            blobCount: UInt32(blobs.count),
            bridgeCount: UInt32(bridges.count)
        )
        let blobData = blobs.isEmpty ? [LiquidBlob(frame: .zero, cornerRadius: 0, blend: 0)] : blobs
        let zeroBridge = LiquidBridge(from: .zero, to: .zero, startRadius: 0, endRadius: 0, blend: 0)
        let bridgeData = bridges.isEmpty ? [zeroBridge] : bridges

        encoder.setRenderPipelineState(gpu.pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LiquidUniforms>.stride, index: 0)
        encoder.setFragmentBytes(blobData, length: MemoryLayout<LiquidBlob>.stride * blobData.count, index: 1)
        encoder.setFragmentBytes(bridgeData, length: MemoryLayout<LiquidBridge>.stride * bridgeData.count, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }

    private func updateDriver() {
        if wantsFrames, window != nil {
            driver.start()
        } else {
            driver.stop()
        }
    }
}

extension UIColor {
    fileprivate func liquidComponents(with traits: UITraitCollection) -> SIMD4<Float> {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return SIMD4(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
