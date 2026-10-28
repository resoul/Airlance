import Observers
import UIKit

open class AirlanceViewController<Presentation: ThemedPresentation>: UIViewController {
    public let presentationSource: any PresentationSource<Presentation>

    private var presentationObservation: ObservationToken?

    public var presentation: Presentation {
        presentationSource.presentation
    }

    public init(presentationSource: any PresentationSource<Presentation>) {
        self.presentationSource = presentationSource
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard presentationObservation == nil else {
            return
        }

        presentationObservation = presentationSource.observe { [weak self] presentation in
            self?.apply(presentation)
        }
    }

    open func apply(_ presentation: Presentation) {
        view.backgroundColor = presentation.theme.colors.background
    }
}
