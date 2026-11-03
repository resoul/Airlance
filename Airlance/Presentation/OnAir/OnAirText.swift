import ListUI
import UIKit

enum OnAirText {
    static func string(
        _ text: String,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment

        return NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
    }

    static func stack(
        _ lines: [NSAttributedString],
        width: CGFloat,
        alignment: NSTextAlignment,
        maxLines: [UInt] = [],
        spacing: CGFloat = 2
    ) -> ListRowContent {
        var elements: [ListRowElement] = []
        var y: CGFloat = 0
        for (index, line) in lines.enumerated() {
            let limit = maxLines.indices.contains(index) ? maxLines[index] : 1
            let measured = ListRowContent.measure(line, width: width, lines: limit)
            let x: CGFloat = switch alignment {
            case .right:
                width - measured.width
            case .center:
                (width - measured.width) / 2
            default:
                0
            }
            let frame = CGRect(x: x, y: y, width: measured.width, height: measured.height)
            elements.append(.text(line, lines: limit, frame: frame))
            y += measured.height + (index < lines.count - 1 ? spacing : 0)
        }

        return ListRowContent(size: CGSize(width: width, height: y), elements: elements)
    }
}
