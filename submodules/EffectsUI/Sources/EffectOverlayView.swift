import LiquidUI
import Metal
import QuartzCore
import UIKit

@MainActor
protocol OverlayEffect: AnyObject {
    var lifetime: TimeInterval { get }

    func encode(into commandBuffer: any MTLCommandBuffer, target: any MTLTexture, frame: EffectFrame, gpu: EffectsGPU)
}

struct EffectFrame {
    let time: Float
    let deltaTime: Float
    let scale: Float
}

@MainActor
final class EffectOverlayView: UIView {
    var onFinish: (@MainActor () -> Void)?

    private let effect: any OverlayEffect
    private let gpu: EffectsGPU
    private var time: CFTimeInterval = 0
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.step(deltaTime)
    }

    override class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    private var metalLayer: CAMetalLayer? {
        layer as? CAMetalLayer
    }

    init(effect: any OverlayEffect, gpu: EffectsGPU, frame: CGRect, scale: CGFloat) {
        self.effect = effect
        self.gpu = gpu
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentScaleFactor = scale
        metalLayer?.device = gpu.device
        metalLayer?.pixelFormat = gpu.pixelFormat
        metalLayer?.isOpaque = false
        metalLayer?.framebufferOnly = true
        metalLayer?.contentsScale = scale
        let pixels = CGSize(width: (frame.width * scale).rounded(), height: (frame.height * scale).rounded())
        metalLayer?.drawableSize = pixels
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func start() {
        driver.start()
        step(0)
    }

    private func step(_ deltaTime: CFTimeInterval) {
        time += deltaTime
        guard time < effect.lifetime else {
            driver.stop()
            removeFromSuperview()
            onFinish?()

            return
        }

        render(deltaTime: deltaTime)
    }

    private func render(deltaTime: CFTimeInterval) {
        guard
            let metalLayer,
            let drawable = metalLayer.nextDrawable(),
            let commandBuffer = gpu.queue.makeCommandBuffer()
        else {
            return
        }

        let frame = EffectFrame(time: Float(time), deltaTime: Float(deltaTime), scale: Float(contentScaleFactor))
        effect.encode(into: commandBuffer, target: drawable.texture, frame: frame, gpu: gpu)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

extension MTLRenderPassDescriptor {
    static func clearing(_ target: any MTLTexture) -> MTLRenderPassDescriptor {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        return pass
    }
}
