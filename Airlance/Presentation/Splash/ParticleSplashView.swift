import Haptics
import ParticlesUI
import UIKit

@MainActor
final class ParticleSplashView: UIView {
    private static let word = "AIRLANCE"
    private static let particleCount = 9_000
    private static let firstLetter: TimeInterval = 0.15
    private static let letterStep: TimeInterval = 0.12
    private static let burstAt: TimeInterval = 1.75
    private static let burstDuration: TimeInterval = 0.9
    private static var didShow = false

    private let backdrop = UIView()
    private let chart = ParticleChartView()
    private let tint: UIColor
    private var letters: [CGPath] = []
    private var counts: [Int] = []
    private var timeline: Task<Void, Never>?
    private var startTime = CACurrentMediaTime()
    private var isBursting = false

    static func present(in window: UIWindow, tint: UIColor) {
        guard !didShow else {
            return
        }

        didShow = true
        let splash = ParticleSplashView(frame: window.bounds, tint: tint)
        splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(splash)
        splash.start()
    }

    private init(frame: CGRect, tint: UIColor) {
        self.tint = tint
        super.init(frame: frame)
        backdrop.backgroundColor = .systemBackground
        backdrop.frame = bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(backdrop)
        chart.frame = bounds
        chart.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        chart.particleCount = Self.particleCount
        chart.repelsTouches = false
        chart.isUserInteractionEnabled = false
        addSubview(chart)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skip)))
        isAccessibilityElement = true
        accessibilityLabel = "Airlance"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private var focus: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func start() {
        guard ParticleChartView.isSupported, !UIAccessibility.isReduceMotionEnabled else {
            showStill()

            return
        }

        prepareLetters()
        startTime = CACurrentMediaTime()
        chart.show([cloud(count: Self.particleCount)], from: focus)
        timeline = Task { [weak self] in
            for index in 0..<Self.word.count {
                let at = Self.firstLetter + Self.letterStep * Double(index)
                await self?.wait(until: at)
                guard !Task.isCancelled else {
                    return
                }

                self?.reveal(upTo: index + 1)
            }
            await self?.wait(until: Self.burstAt)
            if !Task.isCancelled {
                self?.burst()
            }
        }
    }

    private func prepareLetters() {
        let probe = UIFont.systemFont(ofSize: 100, weight: .black)
        let width = (Self.word as NSString).size(withAttributes: [.font: probe]).width
        let size = min(100 * bounds.width * 0.84 / max(width, 1), 96)
        letters = ParticleShapes.letters(Self.word, font: .systemFont(ofSize: size, weight: .black), center: focus)
        let areas = letters.map { path in
            Double(path.boundingBoxOfPath.width * path.boundingBoxOfPath.height)
        }
        counts = ParticleSegment.split(Self.particleCount, weights: areas)
    }

    private func reveal(upTo shown: Int) {
        guard !isBursting else {
            return
        }

        var segments = letters.prefix(shown).enumerated().map { index, path in
            letter(index, path: path)
        }
        let rest = Self.particleCount - counts.prefix(shown).reduce(0, +)
        if rest > 0 {
            segments.append(cloud(count: rest))
        }
        chart.show(segments)
        superview?.bringSubviewToFront(self)
        Haptics.play(.selection)
    }

    private func letter(_ index: Int, path: CGPath?) -> ParticleSegment {
        ParticleSegment(
            path: path,
            count: counts[index],
            color: Self.shifted(tint, by: CGFloat(index) * 0.025),
            pointSize: 1.7,
            stiffness: 1.6,
            order: .horizontal
        )
    }

    private func cloud(count: Int) -> ParticleSegment {
        let radius = min(bounds.width, bounds.height) * 0.18
        let path = CGPath(
            ellipseIn: CGRect(x: focus.x - radius, y: focus.y - radius, width: radius * 2, height: radius * 2),
            transform: nil
        )

        return ParticleSegment(path: path, count: count, color: tint, alpha: 0.35, pointSize: 1.2, stiffness: 0.5)
    }

    @objc
    private func skip() {
        timeline?.cancel()
        if letters.isEmpty {
            finish(after: 0)
        } else {
            burst()
        }
    }

    private func burst() {
        guard !isBursting else {
            return
        }

        isBursting = true
        isUserInteractionEnabled = false
        let segments = letters.indices.map { index in
            letter(index, path: nil)
        }
        chart.show(segments, release: .burst, around: focus, duration: Self.burstDuration)
        Haptics.play(.tap)
        UIView.animate(withDuration: 0.45, delay: 0.1, options: .curveEaseOut) {
            self.backdrop.alpha = 0
        }
        finish(after: Self.burstDuration)
    }

    private func showStill() {
        let label = UILabel(frame: bounds)
        label.text = Self.word
        label.font = .systemFont(ofSize: 44, weight: .black)
        label.textColor = tint
        label.textAlignment = .center
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(label)
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.35, delay: 0.6) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    private func finish(after delay: TimeInterval) {
        UIView.animate(withDuration: 0.3, delay: delay) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    private func wait(until time: TimeInterval) async {
        let remaining = time - (CACurrentMediaTime() - startTime)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
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
