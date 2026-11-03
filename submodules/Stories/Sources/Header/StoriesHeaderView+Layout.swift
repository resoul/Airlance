import LiquidUI
import UIKit

extension StoriesHeaderView {
    var stackArea: CGRect {
        let group = groupStart(titleWidth: titleWidth)

        return CGRect(x: group - 12, y: safeTop, width: stackWidth + 24, height: Self.barHeight)
    }

    private var titleWidth: CGFloat {
        ceil(titleLabel.intrinsicContentSize.width)
    }

    private var stackWidth: CGFloat {
        let count = min(entries.count, Self.stackCount)
        guard count > 0 else {
            return 0
        }

        return Self.stackSize + CGFloat(count - 1) * Self.stackStep + 8
    }

    func place() {
        background.frame = CGRect(x: 0, y: 0, width: bounds.width, height: visibleHeight)

        let width = titleWidth
        let start = groupStart(titleWidth: width)
        let collapsedX = start + stackWidth
        let centeredX = (bounds.width - width) / 2
        titleLabel.frame = CGRect(
            x: collapsedX + (centeredX - collapsedX) * expansion,
            y: safeTop,
            width: width,
            height: Self.barHeight
        )

        var blobs: [LiquidBlob] = []
        for (index, entry) in entries.enumerated().reversed() {
            if let blob = place(entry, at: index, groupStart: start) {
                blobs.append(blob)
            }
        }
        canvas.blobs = blobs
    }

    private func groupStart(titleWidth: CGFloat) -> CGFloat {
        (bounds.width - stackWidth - titleWidth) / 2
    }

    private func place(_ entry: StoryStripEntry, at index: Int, groupStart: CGFloat) -> LiquidBlob? {
        let openness = min(max(entry.spring.value, 0), 1.15)
        let progress = min(openness, 1)
        let slot = CGFloat(min(index, Self.stackCount - 1))
        let stack = CGPoint(x: groupStart + Self.stackSize / 2 + slot * Self.stackStep, y: safeTop + Self.barHeight / 2)
        let rowY = safeTop + Self.barHeight + 6 + Self.expandedSize / 2
        let row = CGPoint(
            x: Self.rowInset + Self.slotWidth * (CGFloat(index) + 0.5) - rowScroll.contentOffset.x,
            y: rowY
        )

        var center = CGPoint(
            x: stack.x + (row.x - stack.x) * openness,
            y: stack.y + (row.y - stack.y) * openness
        )
        center.y += sin(progress * .pi) * 10
        let size = Self.stackSize + (Self.expandedSize - Self.stackSize) * min(openness, 1.05)
        let alpha = index < Self.stackCount ? 1 : smoothstep(0.05, 0.4, openness)
        entry.place(center: center, size: size, openness: openness, alpha: alpha)

        entry.name.frame = CGRect(
            x: row.x - Self.slotWidth / 2,
            y: rowY + Self.expandedSize / 2 + 6,
            width: Self.slotWidth,
            height: ceil(entry.name.font.lineHeight)
        )
        entry.name.alpha = smoothstep(0.7, 1, openness)
        guard entry.peer.hasUnseen, alpha > 0 else {
            return nil
        }

        let radius = (size / 2 + 2.5) * alpha
        let frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        return LiquidBlob(frame: frame, cornerRadius: radius, blend: 14 * (1 - progress) + 1)
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let t = min(max((value - edge0) / (edge1 - edge0), 0), 1)

        return t * t * (3 - 2 * t)
    }
}
