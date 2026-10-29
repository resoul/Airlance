import ChatHistory
import CoreGraphics

struct PhotoMosaic: Sendable {
    static let spacing: CGFloat = 2

    let size: CGSize
    let frames: [CGRect]

    init(_ photos: [MessagePhoto], maxWidth: CGFloat) {
        let ratios = photos.map { photo in
            CGFloat(min(max(photo.aspectRatio, 0.5), 2.2))
        }
        guard ratios.count > 1 else {
            let single = Self.single(ratios.first ?? 1, maxWidth: maxWidth)
            size = single
            frames = [CGRect(origin: .zero, size: single)]

            return
        }

        let width = floor(maxWidth)
        var rows: [[CGFloat]] = []
        var start = 0
        for count in Self.rowCounts(ratios) {
            rows.append(Array(ratios[start..<start + count]))
            start += count
        }
        let heights = Self.rowHeights(rows, width: width)
        var frames: [CGRect] = []
        var y: CGFloat = 0
        for (row, height) in zip(rows, heights) {
            frames += Self.frames(row, y: y, height: height, width: width)
            y += height + Self.spacing
        }
        size = CGSize(width: width, height: y - Self.spacing)
        self.frames = frames
    }

    private static func single(_ ratio: CGFloat, maxWidth: CGFloat) -> CGSize {
        let maxHeight = maxWidth * 1.25
        var width = maxWidth
        var height = width / ratio
        if height > maxHeight {
            height = maxHeight
            width = max(maxWidth * 0.6, height * ratio)
        }

        return CGSize(width: floor(width), height: floor(height))
    }

    private static func rowCounts(_ ratios: [CGFloat]) -> [Int] {
        let wideFirst = ratios[0] > 1.2
        switch ratios.count {
        case 2:
            return ratios.allSatisfy { ratio in
                ratio > 1.2
            } ? [1, 1] : [2]
        case 3:
            return wideFirst ? [1, 2] : [3]
        case 4:
            return wideFirst ? [1, 3] : [2, 2]
        case 5:
            return [2, 3]
        case 6:
            return [3, 3]
        case 7:
            return [2, 2, 3]
        case 8:
            return [2, 3, 3]
        case 9:
            return [3, 3, 3]
        default:
            return [3, 3, ratios.count - 6]
        }
    }

    private static func rowHeights(_ rows: [[CGFloat]], width: CGFloat) -> [CGFloat] {
        let natural = rows.map { row in
            let available = width - spacing * CGFloat(row.count - 1)

            return min(max(available / row.reduce(0, +), width * 0.22), width * 0.8)
        }
        let total = natural.reduce(0, +) + spacing * CGFloat(rows.count - 1)
        let limit = width * 1.4
        guard total > limit else {
            return natural.map(floor)
        }

        let scale = (limit - spacing * CGFloat(rows.count - 1)) / natural.reduce(0, +)

        return natural.map { height in
            floor(height * scale)
        }
    }

    private static func frames(_ row: [CGFloat], y: CGFloat, height: CGFloat, width: CGFloat) -> [CGRect] {
        let available = width - spacing * CGFloat(row.count - 1)
        let sum = row.reduce(0, +)
        var x: CGFloat = 0
        var frames: [CGRect] = []
        for (index, ratio) in row.enumerated() {
            let tile = index == row.count - 1 ? width - x : floor(available * ratio / sum)
            frames.append(CGRect(x: x, y: y, width: tile, height: height))
            x += tile + spacing
        }

        return frames
    }
}
