import Metal
import UIKit

private struct DustGrain {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var color: SIMD4<Float>
    var release: Float
    var seed: Float
    var alive: Float
    var life: Float
}

private struct DustUniforms {
    var viewport: SIMD2<Float>
    var scale: Float
    var time: Float
    var element: SIMD4<Float>
    var grain: Float
    var columns: UInt32
    var rows: UInt32
    var releaseWindow: Float
    var wind: SIMD2<Float>
    var gravity: Float
    var dt: Float
}

@MainActor
final class DustEffect: OverlayEffect {
    private static let wind = SIMD2<Float>(0, -80)
    private static let gravity: Float = -140
    private static let releaseWindow: Float = 0.9

    let lifetime: TimeInterval = Double(DustEffect.releaseWindow) + 1.3

    private let element: CGRect
    private let texture: any MTLTexture
    private let grain: CGFloat
    private let columns: Int
    private let rows: Int
    private let grains: any MTLBuffer
    private var spawned = false

    init?(element: CGRect, texture: any MTLTexture, gpu: EffectsGPU) {
        let grain = max(0.9, sqrt(element.width * element.height / 40_000))
        let columns = max(1, Int(ceil(element.width / grain)))
        let rows = max(1, Int(ceil(element.height / grain)))
        let length = MemoryLayout<DustGrain>.stride * columns * rows
        guard let grains = gpu.device.makeBuffer(length: length, options: .storageModePrivate) else {
            return nil
        }

        self.element = element
        self.texture = texture
        self.grain = grain
        self.columns = columns
        self.rows = rows
        self.grains = grains
    }

    func encode(into commandBuffer: any MTLCommandBuffer, target: any MTLTexture, frame: EffectFrame, gpu: EffectsGPU) {
        guard
            let spawn = gpu.computePipeline("dust_spawn"),
            let update = gpu.computePipeline("dust_update"),
            let grainPipeline = gpu.renderPipeline(vertex: "dust_grain_vertex", fragment: "dust_grain_fragment"),
            let elementPipeline = gpu.renderPipeline(vertex: "dust_element_vertex", fragment: "dust_element_fragment")
        else {
            return
        }

        var uniforms = uniforms(target: target, frame: frame)
        let count = columns * rows
        if let compute = commandBuffer.makeComputeCommandEncoder() {
            let pipeline = spawned ? update : spawn
            compute.setComputePipelineState(pipeline)
            compute.setBuffer(grains, offset: 0, index: 0)
            compute.setBytes(&uniforms, length: MemoryLayout<DustUniforms>.stride, index: 1)
            if !spawned {
                compute.setTexture(texture, index: 0)
                spawned = true
            }
            let width = pipeline.threadExecutionWidth
            compute.dispatchThreadgroups(
                MTLSize(width: (count + width - 1) / width, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
            )
            compute.endEncoding()
        }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: .clearing(target)) else {
            return
        }

        encoder.setRenderPipelineState(elementPipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<DustUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DustUniforms>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.setRenderPipelineState(grainPipeline)
        encoder.setVertexBuffer(grains, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<DustUniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: count)
        encoder.endEncoding()
    }

    private func uniforms(target: any MTLTexture, frame: EffectFrame) -> DustUniforms {
        DustUniforms(
            viewport: SIMD2(Float(target.width), Float(target.height)),
            scale: frame.scale,
            time: frame.time,
            element: SIMD4(Float(element.minX), Float(element.minY), Float(element.width), Float(element.height)),
            grain: Float(grain),
            columns: UInt32(columns),
            rows: UInt32(rows),
            releaseWindow: Self.releaseWindow,
            wind: Self.wind,
            gravity: Self.gravity,
            dt: frame.deltaTime
        )
    }
}
