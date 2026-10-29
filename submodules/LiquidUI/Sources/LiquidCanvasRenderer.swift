import Foundation
import Metal
import QuartzCore

struct LiquidCanvasFrame: Sendable {
    let size: CGSize
    let uniforms: LiquidUniforms
    let blobs: [LiquidBlob]
    let bridges: [LiquidBridge]
}

final class LiquidCanvasRenderer: @unchecked Sendable {
    private let layer: CAMetalLayer
    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private let queue = DispatchQueue(label: "LiquidUI.Canvas", qos: .userInteractive)

    @MainActor
    init(layer: CAMetalLayer, gpu: LiquidGPU) {
        self.layer = layer
        commandQueue = gpu.queue
        pipeline = gpu.pipeline
    }

    func render(_ frame: LiquidCanvasFrame, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            autoreleasepool {
                draw(frame, completion: completion)
            }
        }
    }

    private func draw(_ frame: LiquidCanvasFrame, completion: @escaping @Sendable (Bool) -> Void) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(), let drawable = layer.nextDrawable() else {
            completion(false)

            return
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            completion(false)

            return
        }

        encode(frame, into: encoder)
        encoder.endEncoding()
        commandBuffer.addCompletedHandler { buffer in
            completion(buffer.status == .completed)
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func encode(_ frame: LiquidCanvasFrame, into encoder: any MTLRenderCommandEncoder) {
        guard !frame.blobs.isEmpty || !frame.bridges.isEmpty else {
            return
        }

        var uniforms = frame.uniforms
        let blobs = frame.blobs.isEmpty ? [LiquidBlob(frame: .zero, cornerRadius: 0, blend: 0)] : frame.blobs
        let zeroBridge = LiquidBridge(from: .zero, to: .zero, startRadius: 0, endRadius: 0, blend: 0)
        let bridges = frame.bridges.isEmpty ? [zeroBridge] : frame.bridges

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LiquidUniforms>.stride, index: 0)
        encoder.setFragmentBytes(blobs, length: MemoryLayout<LiquidBlob>.stride * blobs.count, index: 1)
        encoder.setFragmentBytes(bridges, length: MemoryLayout<LiquidBridge>.stride * bridges.count, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
