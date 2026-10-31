import UIKit

enum BlobShape {
    private static let points = 9

    static func path(in rect: CGRect, phase: CGFloat, level: CGFloat) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let amplitude = 0.025 + 0.07 * min(max(level, 0), 1)
        let corners = (0..<points).map { index -> CGPoint in
            let angle = CGFloat(index) / CGFloat(points) * .pi * 2
            let wave = sin(phase * 1.7 + CGFloat(index) * 2.1) * 0.6 + sin(phase * 2.9 + CGFloat(index) * 1.3) * 0.4
            let distance = radius * (1 - amplitude + amplitude * wave)

            return CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
        }

        return smooth(corners)
    }

    private static func smooth(_ corners: [CGPoint]) -> CGPath {
        let path = UIBezierPath()
        let count = corners.count
        path.move(to: midpoint(corners[count - 1], corners[0]))
        for index in 0..<count {
            let point = corners[index]
            let next = corners[(index + 1) % count]
            path.addQuadCurve(to: midpoint(point, next), controlPoint: point)
        }
        path.close()

        return path.cgPath
    }

    private static func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }
}

enum VideoNoteLevels {
    static func level(_ levels: [UInt8], at progress: Double) -> CGFloat {
        guard !levels.isEmpty else {
            return 0.3
        }

        let index = min(levels.count - 1, max(0, Int(progress * Double(levels.count))))

        return CGFloat(levels[index]) / 255
    }

    static func encode(_ samples: [Float], bars: Int = 64) -> [UInt8] {
        guard !samples.isEmpty else {
            return []
        }

        let step = max(1, samples.count / bars)

        return stride(from: 0, to: samples.count, by: step).map { start in
            let slice = samples[start..<min(start + step, samples.count)]
            let value = slice.reduce(0, +) / Float(slice.count)

            return UInt8(min(max(value, 0), 1) * 255)
        }
    }
}
