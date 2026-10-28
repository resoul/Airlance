import CoreGraphics

public struct LiquidBlob: Sendable {
    var box: SIMD4<Float>
    var params: SIMD4<Float>

    public init(frame: CGRect, cornerRadius: CGFloat, blend: CGFloat) {
        let halfWidth = Float(max(frame.width / 2, 0))
        let halfHeight = Float(max(frame.height / 2, 0))
        box = SIMD4(Float(frame.midX), Float(frame.midY), halfWidth, halfHeight)
        params = SIMD4(Float(cornerRadius), Float(blend), 0, 0)
    }

    var extent: CGRect {
        let blend = CGFloat(params.y)
        let rect = CGRect(
            x: CGFloat(box.x - box.z),
            y: CGFloat(box.y - box.w),
            width: CGFloat(box.z * 2),
            height: CGFloat(box.w * 2)
        )

        return rect.insetBy(dx: -blend, dy: -blend)
    }
}

public struct LiquidBridge: Sendable {
    var segment: SIMD4<Float>
    var params: SIMD4<Float>

    public init(from start: CGPoint, to end: CGPoint, startRadius: CGFloat, endRadius: CGFloat, blend: CGFloat) {
        segment = SIMD4(Float(start.x), Float(start.y), Float(end.x), Float(end.y))
        params = SIMD4(Float(startRadius), Float(endRadius), Float(blend), 0)
    }

    var extent: CGRect {
        let radius = CGFloat(max(params.x, params.y) + params.z)
        let rect = CGRect(
            x: CGFloat(min(segment.x, segment.z)),
            y: CGFloat(min(segment.y, segment.w)),
            width: CGFloat(abs(segment.z - segment.x)),
            height: CGFloat(abs(segment.w - segment.y))
        )

        return rect.insetBy(dx: -radius, dy: -radius)
    }
}

struct LiquidUniforms {
    var scale: Float
    var gloss: Float
    var rimWidth: Float
    var unused: Float = 0
    var color: SIMD4<Float>
    var bounds: SIMD4<Float>
    var blobCount: UInt32
    var bridgeCount: UInt32
}
