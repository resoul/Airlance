import Theme
import UIKit

extension AppTheme {
    var groupedBackground: UIColor {
        appearance == .dark ? colors.background : colors.surface
    }

    var groupedCell: UIColor {
        appearance == .dark ? colors.surface : colors.background
    }
}
