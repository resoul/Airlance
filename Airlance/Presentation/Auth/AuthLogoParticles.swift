import Haptics
import ParticlesUI
import UIKit

@MainActor
final class AuthLogoParticles {
    private static let particleCount = 7_000
    private static let logoFontSize: CGFloat = 52
    private static let logoPointSize: CGFloat = 1.4
    private static let firstLetter: Duration = .milliseconds(150)
    private static let letterStep: Duration = .milliseconds(120)
    private static let holdBeforeMove: Duration = .milliseconds(650)

    static var isAvailable: Bool {
        ParticleChartView.isHardwareSupported && !UIAccessibility.isReduceMotionEnabled
    }

    let chart = ParticleChartView(ignoresPowerSaving: true)
    var onContentReveal: (@MainActor () -> Void)?

    private var tint: UIColor
    private var playsIntro: Bool
    private var slot = CGRect.null
    private var isPlaced = false
    private var intro: Task<Void, Never>?

    init(tint: UIColor, playsIntro: Bool) {
        self.tint = tint
        self.playsIntro = playsIntro
        chart.particleCount = Self.particleCount
        chart.repelsTouches = false
        chart.touchArea = .zero
    }

    func layout(slot newSlot: CGRect) {
        guard newSlot != slot, newSlot.width > 0, chart.bounds.width > 0 else {
            return
        }

        slot = newSlot
        if playsIntro {
            playsIntro = false
            startIntro()
        } else if intro == nil {
            place()
        }
    }

    func update(tint newTint: UIColor) {
        guard newTint != tint else {
            return
        }

        tint = newTint
        if isPlaced {
            place()
        }
    }

    private func startIntro() {
        let center = CGPoint(x: chart.bounds.midX, y: chart.bounds.midY)
        let wordmark = ParticleWordmark(
            center: center,
            width: chart.bounds.width * 0.84,
            maxFontSize: 96,
            particleCount: Self.particleCount,
            tint: tint
        )
        chart.show([cloud(center: center, count: Self.particleCount)], from: center)
        chart.touchArea = nil
        chart.onTap = { [weak self] _ in
            self?.finishIntro()
        }
        intro = Task { [weak self] in
            for shown in 1...wordmark.letterCount {
                try? await Task.sleep(for: shown == 1 ? Self.firstLetter : Self.letterStep)
                guard !Task.isCancelled else {
                    return
                }

                self?.reveal(wordmark, shown: shown, center: center)
            }
            try? await Task.sleep(for: Self.holdBeforeMove)
            if !Task.isCancelled {
                self?.finishIntro()
            }
        }
    }

    private func reveal(_ wordmark: ParticleWordmark, shown: Int, center: CGPoint) {
        var segments = wordmark.segments(shown: shown)
        let rest = Self.particleCount - wordmark.placedCount(shown: shown)
        if rest > 0 {
            segments.append(cloud(center: center, count: rest))
        }
        chart.show(segments)
        Haptics.play(.selection)
    }

    private func finishIntro() {
        guard let intro else {
            return
        }

        intro.cancel()
        self.intro = nil
        Haptics.play(.tap)
        place()
        onContentReveal?()
    }

    private func place() {
        let wordmark = ParticleWordmark(
            center: CGPoint(x: slot.midX, y: slot.midY),
            width: slot.width,
            maxFontSize: Self.logoFontSize,
            particleCount: Self.particleCount,
            tint: tint,
            pointSize: Self.logoPointSize
        )
        chart.show(wordmark.segments(shown: wordmark.letterCount), from: CGPoint(x: slot.midX, y: slot.midY))
        chart.onTap = nil
        chart.touchArea = slot.insetBy(dx: -12, dy: -24)
        chart.repelsTouches = true
        isPlaced = true
    }

    private func cloud(center: CGPoint, count: Int) -> ParticleSegment {
        ParticleWordmark.cloud(
            center: center,
            radius: min(chart.bounds.width, chart.bounds.height) * 0.18,
            count: count,
            tint: tint
        )
    }
}
