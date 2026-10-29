import LiquidUI
import os
import QuartzCore

enum HistorySignpost {
    static let signposter = OSSignposter(subsystem: "app.airlance", category: "History")
}

@MainActor
final class HistoryMetrics {
    enum Stage: String, CaseIterable {
        case slice
        case snapshot
        case apply
    }

    struct Sample {
        var last: Double = 0
        var total: Double = 0
        var samples: Double = 0
        var worst: Double = 0

        var average: Double {
            samples > 0 ? total / samples : 0
        }

        mutating func add(_ value: Double) {
            last = value
            total += value
            samples += 1
            worst = max(worst, value)
        }
    }

    private static let hitchInterval: CFTimeInterval = 1.5 / 60

    var onChange: (@MainActor () -> Void)?
    private(set) var samples: [Stage: Sample] = [:]
    private(set) var firstSlice: Double?
    private(set) var built = 0
    private(set) var reused = 0
    private(set) var total = 0
    private(set) var data = 0
    private(set) var items = 0
    private(set) var frames = 0
    private(set) var hitches = 0
    private(set) var worstFrame: Double = 0

    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.frame(deltaTime)
    }

    func start() {
        driver.start()
    }

    func stop() {
        driver.stop()
    }

    func reset() {
        samples = [:]
        built = 0
        reused = 0
        frames = 0
        hitches = 0
        worstFrame = 0
        onChange?()
    }

    func record(_ stage: Stage, seconds: Double) {
        let milliseconds = seconds * 1000
        if stage == .slice, firstSlice == nil {
            firstSlice = milliseconds
        } else {
            samples[stage, default: Sample()].add(milliseconds)
        }
        onChange?()
    }

    func recordSnapshot(built: Int, reused: Int) {
        self.built += built
        self.reused += reused
    }

    func recordWindow(total: Int, data: Int, items: Int) {
        self.total = total
        self.data = data
        self.items = items
        onChange?()
    }

    private func frame(_ deltaTime: CFTimeInterval) {
        frames += 1
        guard deltaTime > Self.hitchInterval, frames > 1 else {
            return
        }

        hitches += 1
        worstFrame = max(worstFrame, deltaTime * 1000)
        onChange?()
    }
}

extension HistoryMetrics {
    var summary: String {
        var lines = ["messages \(total) · data \(data) · items \(items)"]
        if let firstSlice {
            lines.append("first slice \(Self.format(firstSlice)) ms")
        }
        for stage in Stage.allCases {
            let sample = samples[stage] ?? Sample()
            let average = Self.format(sample.average)
            let values = "\(Self.format(sample.last)) · avg \(average) · max \(Self.format(sample.worst))"
            lines.append("\(stage.rawValue) \(values) ms ×\(Int(sample.samples))")
        }
        lines.append("layouts built \(built) · reused \(reused)")
        lines.append("frames \(frames) · >25 ms \(hitches) · worst \(Self.format(worstFrame)) ms")

        return lines.joined(separator: "\n")
    }

    private static func format(_ value: Double) -> String {
        String(format: value < 10 ? "%.2f" : "%.0f", value)
    }
}
