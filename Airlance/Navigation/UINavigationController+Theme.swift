import Theme
import UIKit

extension UINavigationController {
    func apply(_ theme: AppTheme) {
        let colors = theme.colors
        let fonts = theme.fonts

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = colors.background
        appearance.shadowColor = colors.separator
        appearance.titleTextAttributes = [.foregroundColor: colors.textPrimary, .font: fonts.headline]
        appearance.largeTitleTextAttributes = [.foregroundColor: colors.textPrimary, .font: fonts.largeTitle]

        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.tintColor = colors.accent
    }
}
