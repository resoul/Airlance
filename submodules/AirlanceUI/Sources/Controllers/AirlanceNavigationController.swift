import Observers
import Theme
import UIKit

open class AirlanceNavigationController<Presentation: ThemedPresentation>: UINavigationController {
    public let presentationSource: any PresentationSource<Presentation>

    private var presentationObservation: ObservationToken?

    public init(presentationSource: any PresentationSource<Presentation>, prefersLargeTitles: Bool = false) {
        self.presentationSource = presentationSource
        super.init(nibName: nil, bundle: nil)
        navigationBar.prefersLargeTitles = prefersLargeTitles
        apply(presentationSource.presentation.theme)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        presentationObservation = presentationSource.observe { [weak self] presentation in
            self?.apply(presentation.theme)
        }
    }

    open func apply(_ theme: AppTheme) {
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
