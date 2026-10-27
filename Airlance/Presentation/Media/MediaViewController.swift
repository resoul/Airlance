import Observers
import UIKit

struct MediaDependencies {
    let presentationContext: PresentationContext
}

final class MediaViewController: UIViewController {
    private let id: Int
    private let dependencies: MediaDependencies
    private let profileButton: UIButton
    private let notificationButton: UIButton
    private var presentationObservation: ObservationToken?

    init(id: Int, dependencies: MediaDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        profileButton = UIButton.action {
            router.open(.profile(id))
        }
        notificationButton = UIButton.action {
            router.show(.chat(DemoChats.next(after: id)))
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeActionButtons([profileButton, notificationButton])

        presentationObservation = dependencies.presentationContext.observe { [weak self] data in
            self?.apply(data)
        }
    }

    private func apply(_ data: PresentationData) {
        let strings = data.strings

        navigationItem.title = strings.mediaTitle(id)
        view.backgroundColor = data.theme.colors.background
        profileButton.apply(title: strings.chatProfile, theme: data.theme)
        notificationButton.apply(title: strings.notificationFrom(DemoChats.next(after: id)), theme: data.theme)
    }
}
