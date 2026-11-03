import CoreGraphics

public enum StoryCollageLayout: String, CaseIterable, Codable, Sendable {
    case rows2
    case columns2
    case rows3
    case oneTwo
    case grid4
    case twoThree
    case grid6

    public var cells: [CGRect] {
        switch self {
        case .rows2:
            Self.grid(columns: 1, rows: 2)
        case .columns2:
            Self.grid(columns: 2, rows: 1)
        case .rows3:
            Self.grid(columns: 1, rows: 3)
        case .oneTwo:
            [CGRect(x: 0, y: 0, width: 1, height: 0.5)] + Self.row(count: 2, y: 0.5, height: 0.5)
        case .grid4:
            Self.grid(columns: 2, rows: 2)
        case .twoThree:
            Self.row(count: 2, y: 0, height: 0.5) + Self.row(count: 3, y: 0.5, height: 0.5)
        case .grid6:
            Self.grid(columns: 2, rows: 3)
        }
    }

    public static func fitting(_ count: Int) -> StoryCollageLayout {
        allCases.first { layout in
            layout.cells.count >= count
        } ?? .grid6
    }

    private static func grid(columns: Int, rows: Int) -> [CGRect] {
        (0..<rows).flatMap { row in
            Self.row(count: columns, y: CGFloat(row) / CGFloat(rows), height: 1 / CGFloat(rows))
        }
    }

    private static func row(count: Int, y: CGFloat, height: CGFloat) -> [CGRect] {
        (0..<count).map { index in
            CGRect(x: CGFloat(index) / CGFloat(count), y: y, width: 1 / CGFloat(count), height: height)
        }
    }
}
