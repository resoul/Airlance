import Metal
import UIKit

private struct BurnUniforms {
    var viewport: SIMD2<Float>
    var scale: Float
    var time: Float
    var element: SIMD4<Float>
    var origin: SIMD2<Float>
    var speed: Float
    var roughness: Float
}

@MainActor
final class BurnEffect: OverlayEffect {
    private static let duration: CGFloat = 1.8
    private static let roughness: CGFloat = 0.45

    let lifetime: TimeInterval = Double(BurnEffect.duration) + 1

    private let element: CGRect
    private let texture: any MTLTexture
    private let origin: CGPoint
    private let speed: CGFloat

    init(element: CGRect, texture: any MTLTexture) {
        let origin = CGPoint(x: element.minX + 12, y: element.maxY - 12)
        let corners = [
            CGPoint(x: element.minX, y: element.minY),
            CGPoint(x: element.maxX, y: element.minY),
            CGPoint(x: element.minX, y: element.maxY),
            CGPoint(x: element.maxX, y: element.maxY),
        ]
        let distances = corners.map { corner in
            hypot(corner.x - origin.x, corner.y - origin.y)
        }
        let reach = distances.max() ?? 1
        self.element = element
        self.texture = texture
        self.origin = origin
        speed = reach / max(Self.duration - Self.roughness, 0.3)
    }

    func encode(into commandBuffer: any MTLCommandBuffer, target: any MTLTexture, frame: EffectFrame, gpu: EffectsGPU) {
        guard
            let pipeline = gpu.renderPipeline(vertex: "burn_vertex", fragment: "burn_fragment"),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: .clearing(target))
        else {
            return
        }

        var uniforms = BurnUniforms(
            viewport: SIMD2(Float(target.width), Float(target.height)),
            scale: frame.scale,
            time: frame.time,
            element: SIMD4(Float(element.minX), Float(element.minY), Float(element.width), Float(element.height)),
            origin: SIMD2(Float(origin.x), Float(origin.y)),
            speed: Float(speed),
            roughness: Float(Self.roughness)
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<BurnUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}
