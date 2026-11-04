import Haptics
import ParticlesUI
import UIKit

@MainActor
final class ParticleSplashView: UIView {
    private static let particleCount = 9_000
    private static let firstLetter: TimeInterval = 0.15
    private static let letterStep: TimeInterval = 0.12
    private static let burstAt: TimeInterval = 1.75
    private static let burstDuration: TimeInterval = 0.9
    private static var didShow = false

    private let backdrop = UIView()
    private let chart = ParticleChartView()
    private let tint: UIColor
    private var wordmark: ParticleWordmark?
    private var timeline: Task<Void, Never>?
    private var startTime = CACurrentMediaTime()
    private var isBursting = false

    static func claimFirstShow() -> Bool {
        guard !didShow else {
            return false
        }

        didShow = true

        return true
    }

    static func present(in window: UIWindow, tint: UIColor) {
        guard claimFirstShow() else {
            return
        }

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

        let wordmark = ParticleWordmark(
            center: focus,
            width: bounds.width * 0.84,
            maxFontSize: 96,
            particleCount: Self.particleCount,
            tint: tint
        )
        self.wordmark = wordmark
        startTime = CACurrentMediaTime()
        chart.show([cloud(count: Self.particleCount)], from: focus)
        timeline = Task { [weak self] in
            for index in 0..<wordmark.letterCount {
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

    private func reveal(upTo shown: Int) {
        guard !isBursting, let wordmark else {
            return
        }

        var segments = wordmark.segments(shown: shown)
        let rest = Self.particleCount - wordmark.placedCount(shown: shown)
        if rest > 0 {
            segments.append(cloud(count: rest))
        }
        chart.show(segments)
        superview?.bringSubviewToFront(self)
        Haptics.play(.selection)
    }

    private func cloud(count: Int) -> ParticleSegment {
        ParticleWordmark.cloud(
            center: focus,
            radius: min(bounds.width, bounds.height) * 0.18,
            count: count,
            tint: tint
        )
    }

    @objc
    private func skip() {
        timeline?.cancel()
        if wordmark == nil {
            finish(after: 0)
        } else {
            burst()
        }
    }

    private func burst() {
        guard !isBursting, let wordmark else {
            return
        }

        isBursting = true
        isUserInteractionEnabled = false
        chart.show(wordmark.releasedSegments(), release: .burst, around: focus, duration: Self.burstDuration)
        Haptics.play(.tap)
        UIView.animate(withDuration: 0.45, delay: 0.1, options: .curveEaseOut) {
            self.backdrop.alpha = 0
        }
        finish(after: Self.burstDuration)
    }

    private func showStill() {
        let label = UILabel(frame: bounds)
        label.text = ParticleWordmark.word
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
}
