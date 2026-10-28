import CoreGraphics

public struct TabBarLayout: Equatable {
    public static let expandedHeight: CGFloat = 57
    public static let compactHeight: CGFloat = 50
    public static let sideMargin: CGFloat = 16
    public static let innerInset: CGFloat = 6

    public let barFrame: CGRect
    public let itemFrames: [CGRect]
    public let iconScale: CGFloat

    public static func make(
        bounds: CGRect,
        bottomInset: CGFloat,
        count: Int,
        compactProgress: CGFloat
    ) -> TabBarLayout {
        let progress = min(max(compactProgress, 0), 1)
        let fullWidth = bounds.width - sideMargin * 2
        let compactWidth = min(max(fullWidth * 0.78, CGFloat(count) * 52 + innerInset * 2), fullWidth)
        let expandedWidth = (fullWidth + compactWidth) / 2
        let width = interpolate(expandedWidth, compactWidth, progress)
        let height = interpolate(expandedHeight, compactHeight, progress)
        let bottom = bounds.maxY - max(bottomInset * 0.6, 12)
        let barFrame = CGRect(x: bounds.midX - width / 2, y: bottom - height, width: width, height: height)

        return TabBarLayout(
            barFrame: barFrame,
            itemFrames: itemFrames(width: width, height: height, count: count),
            iconScale: interpolate(0.93, 0.85, progress)
        )
    }

    public static func reservedHeight(bottomInset: CGFloat) -> CGFloat {
        expandedHeight + max(bottomInset * 0.6, 12) - bottomInset + 8
    }

    private static func itemFrames(width: CGFloat, height: CGFloat, count: Int) -> [CGRect] {
        guard count > 0 else {
            return []
        }

        let slotWidth = (width - innerInset * 2) / CGFloat(count)

        return (0..<count).map { index in
            CGRect(
                x: innerInset + slotWidth * CGFloat(index),
                y: innerInset,
                width: slotWidth,
                height: height - innerInset * 2
            )
        }
    }

    private static func interpolate(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}
