import Observers
import UIKit

struct ProfileDependencies {
    let presentationContext: PresentationContext
}

final class ProfileViewController: UIViewController {
    private let id: Int
    private let dependencies: ProfileDependencies
    private let messageButton: UIButton
    private let notificationButton: UIButton
    private var presentationObservation: ObservationToken?

    init(id: Int, dependencies: ProfileDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        messageButton = UIButton.action {
            router.show(.chat(id))
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
        navigationItem.largeTitleDisplayMode = .never
        placeActionButtons([messageButton, notificationButton])

        presentationObservation = dependencies.presentationContext.observe { [weak self] data in
            self?.apply(data)
        }
    }

    private func apply(_ data: PresentationData) {
        let strings = data.strings

        navigationItem.title = strings.profileTitle(id)
        view.backgroundColor = data.theme.colors.background
        messageButton.apply(title: strings.profileMessage, theme: data.theme)
        notificationButton.apply(title: strings.notificationFrom(DemoChats.next(after: id)), theme: data.theme)
    }
}
