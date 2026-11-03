import Haptics
import ParticlesUI
import UIKit

extension StorageViewController {
    private static let ringParticles = 8_700
    private static let valueParticles = 2_400
    private static let unitParticles = 900
    private static let minimumShare = 0.03

    private var categories: [StorageCategory] {
        StorageCategory.allCases
    }

    private var shownTotal: Int64 {
        var total: Int64 = 0
        for category in categories where enabled.contains(category) && !clearing.contains(category) {
            total += usage.size(category)
        }

        return total
    }

    func refresh() {
        guard isLoaded, chart.bounds.width > 0, outerRadius > 0 else {
            return
        }

        let segments = ringSegments() + valueSegments()
        chart.particleCount = Self.ringParticles + Self.valueParticles + Self.unitParticles
        chart.show(
            segments,
            from: hasShown ? nil : ringCenter,
            release: effect.release,
            around: ringCenter,
            duration: effect.duration
        )
        hasShown = true
        updateLabels()
    }

    func chartTapped(at point: CGPoint) {
        guard clearing.isEmpty, !lastCounts.isEmpty else {
            return
        }

        let distance = hypot(point.x - ringCenter.x, point.y - ringCenter.y)
        var hit: StorageCategory?
        if distance > innerRadius - 10, distance < outerRadius + 24 {
            let angle = ParticleShapes.angle(of: point, around: ringCenter) / (.pi * 2)
            let total = CGFloat(lastCounts.reduce(0, +))
            var start: CGFloat = 0
            for (index, count) in lastCounts.enumerated() where count > 0 {
                start += CGFloat(count) / max(total, 1)
                if angle < start {
                    hit = categories[index]
                    break
                }
            }
        }
        selected = hit == selected ? nil : hit
        Haptics.play(.selection)
        refresh()
    }

    private func ringSegments() -> [ParticleSegment] {
        if clearing.isEmpty {
            lastCounts = ParticleSegment.split(Self.ringParticles, weights: visualShares())
        }
        guard lastCounts.contains(where: { count in
            count > 0
        }) else {
            return [emptyRing()]
        }

        let paths = ParticleShapes.donut(
            center: ringCenter,
            inner: innerRadius,
            outer: outerRadius,
            shares: lastCounts.map(Double.init),
            pop: categories.map { category in
                category == selected ? 10 : 0
            }
        )

        return categories.enumerated().map { index, category in
            let isReleased = clearing.contains(category)
            let row = rows[index]

            return ParticleSegment(
                path: isReleased ? nil : paths[index],
                count: lastCounts[index],
                color: category.color,
                alpha: selected == nil || selected == category ? 1 : 0.3,
                pointSize: 2,
                order: .angle(around: ringCenter),
                home: row.convert(row.valueCenter, to: chart)
            )
        }
    }

    private func emptyRing() -> ParticleSegment {
        let path = ParticleShapes.donut(center: ringCenter, inner: innerRadius, outer: outerRadius, shares: [1])[0]

        return ParticleSegment(
            path: path,
            count: Self.ringParticles,
            color: presentation.theme.colors.textSecondary,
            alpha: 0.25,
            pointSize: 1.6,
            order: .angle(around: ringCenter)
        )
    }

    private func visualShares() -> [Double] {
        let total = Double(shownTotal)
        guard total > 0 else {
            return categories.map { _ in
                0
            }
        }

        return categories.map { category in
            let bytes = usage.size(category)
            guard enabled.contains(category), bytes > 0 else {
                return 0
            }

            return max(Double(bytes) / total, Self.minimumShare)
        }
    }

    private func valueSegments() -> [ParticleSegment] {
        let bytes = selected.map(usage.size) ?? shownTotal
        let text = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        let parts = Self.split(text)
        let color = selected?.color ?? presentation.theme.colors.textPrimary
        let numberFont = Self.font(fitting: parts.number, width: innerRadius * 1.6, size: outerRadius * 0.42)
        let numberCenter = CGPoint(x: ringCenter.x, y: ringCenter.y - outerRadius * 0.08)
        let unitCenter = CGPoint(x: ringCenter.x, y: ringCenter.y + outerRadius * 0.3)
        let unitFont = UIFont.systemFont(ofSize: outerRadius * 0.17, weight: .semibold)

        return [
            ParticleSegment(
                path: ParticleShapes.text(parts.number, font: numberFont, center: numberCenter),
                count: Self.valueParticles,
                color: color,
                pointSize: 1.3,
                stiffness: 3,
                order: .horizontal
            ),
            ParticleSegment(
                path: ParticleShapes.text(parts.unit, font: unitFont, center: unitCenter),
                count: Self.unitParticles,
                color: color,
                alpha: 0.7,
                pointSize: 1,
                stiffness: 3,
                order: .horizontal
            ),
        ]
    }

    private func updateLabels() {
        let strings = presentation.strings
        let total = usage.total
        caption.text = selected?.title(strings) ?? strings.storageUsed
        hint.text = total == 0 ? strings.storageEmpty : strings.storageHint
        for row in rows {
            let bytes = clearing.contains(row.category) && effect != .rows ? 0 : usage.size(row.category)
            let share = total > 0 ? Double(bytes) / Double(total) : 0
            row.isOn = enabled.contains(row.category)
            row.show(bytes: bytes, share: share, isFirst: !hasShown)
        }
        let size = ByteCountFormatter.string(fromByteCount: shownTotal, countStyle: .file)
        let font = HistoryStyle.bold(presentation.theme.fonts.body)
        let title = NSMutableAttributedString(
            string: strings.storageHold + "  ",
            attributes: [.font: font, .foregroundColor: presentation.theme.colors.onAccent]
        )
        title.append(NSAttributedString(
            string: size,
            attributes: [.font: font, .foregroundColor: presentation.theme.colors.onAccent.withAlphaComponent(0.6)]
        ))
        clearButton.apply(title: title, color: presentation.theme.colors.accent)
        clearButton.isEnabled = clearing.isEmpty && shownTotal > 0
    }

    private static func split(_ text: String) -> (number: String, unit: String) {
        guard let space = text.lastIndex(where: { character in
            character.isWhitespace
        }) else {
            return (text, "")
        }

        return (String(text[..<space]), String(text[text.index(after: space)...]))
    }

    private static func font(fitting text: String, width: CGFloat, size: CGFloat) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: .bold)
        let measured = (text as NSString).size(withAttributes: [.font: font]).width
        guard measured > width, measured > 0 else {
            return font
        }

        return UIFont.systemFont(ofSize: size * width / measured, weight: .bold)
    }
}
