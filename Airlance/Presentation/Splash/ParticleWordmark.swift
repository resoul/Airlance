import ParticlesUI
import UIKit

@MainActor
struct ParticleWordmark {
    static let word = "AIRLANCE"

    private let tint: UIColor
    private let pointSize: CGFloat
    private let letters: [CGPath]
    private let counts: [Int]

    init(
        center: CGPoint,
        width: CGFloat,
        maxFontSize: CGFloat,
        particleCount: Int,
        tint: UIColor,
        pointSize: CGFloat = 1.7
    ) {
        let probe = UIFont.systemFont(ofSize: 100, weight: .black)
        let probeWidth = (Self.word as NSString).size(withAttributes: [.font: probe]).width
        let size = min(100 * width / max(probeWidth, 1), maxFontSize)
        let letters = ParticleShapes.letters(Self.word, font: .systemFont(ofSize: size, weight: .black), center: center)
        let areas = letters.map { path in
            Double(path.boundingBoxOfPath.width * path.boundingBoxOfPath.height)
        }
        self.tint = tint
        self.pointSize = pointSize
        self.letters = letters
        counts = ParticleSegment.split(particleCount, weights: areas)
    }

    var letterCount: Int {
        letters.count
    }

    func placedCount(shown: Int) -> Int {
        counts.prefix(shown).reduce(0, +)
    }

    func segments(shown: Int) -> [ParticleSegment] {
        letters.prefix(shown).enumerated().map { index, path in
            segment(index, path: path)
        }
    }

    func releasedSegments() -> [ParticleSegment] {
        letters.indices.map { index in
            segment(index, path: nil)
        }
    }

    static func cloud(center: CGPoint, radius: CGFloat, count: Int, tint: UIColor) -> ParticleSegment {
        let path = CGPath(
            ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
            transform: nil
        )

        return ParticleSegment(path: path, count: count, color: tint, alpha: 0.35, pointSize: 1.2, stiffness: 0.5)
    }

    private func segment(_ index: Int, path: CGPath?) -> ParticleSegment {
        ParticleSegment(
            path: path,
            count: counts[index],
            color: Self.shifted(tint, by: CGFloat(index) * 0.025),
            pointSize: pointSize,
            stiffness: 1.6,
            order: .horizontal
        )
    }

    private static func shifted(_ color: UIColor, by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color
        }

        let shifted = (hue + amount).truncatingRemainder(dividingBy: 1)

        return UIColor(hue: shifted, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}
