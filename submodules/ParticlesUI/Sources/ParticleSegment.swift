import CoreGraphics
import UIKit

public enum ParticleRelease: Int, Sendable, CaseIterable {
    case dust
    case blackHole
    case home
    case burst
}

public enum ParticleOrder: Sendable {
    case none
    case angle(around: CGPoint)
    case horizontal
}

public struct ParticleSegment {
    public var path: CGPath?
    public var count: Int
    public var color: UIColor
    public var alpha: CGFloat
    public var pointSize: CGFloat
    public var stiffness: CGFloat
    public var order: ParticleOrder
    public var home: CGPoint?

    public init(
        path: CGPath?,
        count: Int,
        color: UIColor,
        alpha: CGFloat = 1,
        pointSize: CGFloat = 2,
        stiffness: CGFloat = 1,
        order: ParticleOrder = .none,
        home: CGPoint? = nil
    ) {
        self.path = path
        self.count = count
        self.color = color
        self.alpha = alpha
        self.pointSize = pointSize
        self.stiffness = stiffness
        self.order = order
        self.home = home
    }

    public static func split(_ total: Int, weights: [Double]) -> [Int] {
        let sum = weights.reduce(0, +)
        guard sum > 0, total > 0 else {
            return weights.map { _ in
                0
            }
        }

        let exact = weights.map { weight in
            Double(total) * weight / sum
        }
        var counts = exact.map { value in
            Int(value.rounded(.down))
        }
        let byRemainder = exact.indices.sorted { lhs, rhs in
            exact[lhs] - Double(counts[lhs]) > exact[rhs] - Double(counts[rhs])
        }
        for index in byRemainder.prefix(total - counts.reduce(0, +)) {
            counts[index] += 1
        }

        return counts
    }
}

public enum ParticleShapes {
    public static func donut(
        center: CGPoint,
        inner: CGFloat,
        outer: CGFloat,
        shares: [Double],
        gap: CGFloat = 0.035,
        pop: [CGFloat] = []
    ) -> [CGPath?] {
        let total = shares.reduce(0, +)
        let visible = shares.filter { share in
            share > 0
        }.count
        var start = -CGFloat.pi / 2
        var paths: [CGPath?] = []
        for (index, share) in shares.enumerated() {
            guard total > 0, share > 0 else {
                paths.append(nil)
                continue
            }

            let sweep = CGFloat(share / total) * .pi * 2
            let spacing = visible > 1 ? min(gap, sweep * 0.3) : 0
            let push = index < pop.count ? pop[index] : 0
            let middle = start + sweep / 2
            let origin = CGPoint(x: center.x + cos(middle) * push, y: center.y + sin(middle) * push)
            let path = CGMutablePath()
            let from = start + spacing / 2
            let to = start + sweep - spacing / 2
            path.addArc(center: origin, radius: outer, startAngle: from, endAngle: to, clockwise: false)
            path.addArc(center: origin, radius: inner, startAngle: to, endAngle: from, clockwise: true)
            path.closeSubpath()
            paths.append(path)
            start += sweep
        }

        return paths
    }

    public static func text(_ string: String, font: UIFont, center: CGPoint) -> CGPath {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: font]))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let path = CGMutablePath()
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName] as? UIFont ?? font
            for (glyph, position) in zip(glyphs, positions) {
                guard let outline = CTFontCreatePathForGlyph(runFont as CTFont, glyph, nil) else {
                    continue
                }

                let x = center.x - bounds.midX + position.x
                let y = center.y + bounds.midY
                let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: x, ty: y)
                path.addPath(outline, transform: transform)
            }
        }

        return path
    }

    public static func letters(_ string: String, font: UIFont, center: CGPoint) -> [CGPath] {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: font]))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        var paths: [CGPath] = []
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName] as? UIFont ?? font
            for (glyph, position) in zip(glyphs, positions) {
                guard let outline = CTFontCreatePathForGlyph(runFont as CTFont, glyph, nil) else {
                    continue
                }

                var transform = CGAffineTransform(
                    a: 1,
                    b: 0,
                    c: 0,
                    d: -1,
                    tx: center.x - bounds.midX + position.x,
                    ty: center.y + bounds.midY
                )
                paths.append(outline.copy(using: &transform) ?? outline)
            }
        }

        return paths
    }

    public static func angle(of point: CGPoint, around center: CGPoint) -> CGFloat {
        var angle = atan2(point.y - center.y, point.x - center.x) + .pi / 2
        if angle < 0 {
            angle += .pi * 2
        }

        return angle
    }
}
