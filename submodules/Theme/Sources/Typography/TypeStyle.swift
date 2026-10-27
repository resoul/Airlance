import UIKit

enum TypeStyle {
    case largeTitle
    case title
    case headline
    case body
    case subheadline
    case caption

    var textStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:
            .largeTitle

        case .title:
            .title2

        case .headline:
            .headline

        case .body:
            .body

        case .subheadline:
            .subheadline

        case .caption:
            .caption1
        }
    }

    var size: CGFloat {
        switch self {
        case .largeTitle:
            34

        case .title:
            22

        case .headline, .body:
            17

        case .subheadline:
            15

        case .caption:
            12
        }
    }

    var weight: UIFont.Weight {
        switch self {
        case .largeTitle:
            .bold

        case .title, .headline:
            .semibold

        case .body, .subheadline, .caption:
            .regular
        }
    }
}
