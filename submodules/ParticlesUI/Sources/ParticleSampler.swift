import CoreGraphics

enum ParticleSampler {
    private struct Random {
        var state: UInt64

        mutating func next() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407

            return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
        }
    }

    static func points(in path: CGPath, count: Int, seed: Int, order: ParticleOrder) -> [CGPoint] {
        guard count > 0 else {
            return []
        }

        let box = path.boundingBoxOfPath
        guard box.width > 0, box.height > 0 else {
            return Array(repeating: CGPoint(x: box.midX, y: box.midY), count: count)
        }

        var random = Random(state: UInt64(truncatingIfNeeded: seed &* 2_654_435_761 &+ 1))
        var points: [CGPoint] = []
        points.reserveCapacity(count)
        var attempts = 0
        while points.count < count, attempts < count * 60 {
            attempts += 1
            let point = CGPoint(x: box.minX + random.next() * box.width, y: box.minY + random.next() * box.height)
            if path.contains(point, using: .winding) {
                points.append(point)
            }
        }
        let fallback = points.first ?? CGPoint(x: box.midX, y: box.midY)
        while points.count < count {
            points.append(points.isEmpty ? fallback : points[points.count % max(1, points.count)])
        }

        return sorted(points, by: order)
    }

    static func seed(_ index: Int) -> Float {
        var random = Random(state: UInt64(index) &+ 0x9E37_79B9)

        return Float(random.next())
    }

    private static func sorted(_ points: [CGPoint], by order: ParticleOrder) -> [CGPoint] {
        switch order {
        case .none:
            points
        case .horizontal:
            points.sorted { lhs, rhs in
                lhs.x < rhs.x
            }
        case .angle(let center):
            points.sorted { lhs, rhs in
                ParticleShapes.angle(of: lhs, around: center) < ParticleShapes.angle(of: rhs, around: center)
            }
        }
    }
}
