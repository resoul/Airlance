import Observers
import UIKit

struct NewChatDependencies {
    let presentationContext: PresentationContext
}

final class NewChatViewController: UIViewController {
    private let dependencies: NewChatDependencies
    private let contactButtons: [UIButton]
    private var presentationObservation: ObservationToken?

    init(dependencies: NewChatDependencies, router: AppRouter) {
        self.dependencies = dependencies
        contactButtons = DemoChats.ids.map { id in
            UIButton.action {
                router.open(.profile(id))
            }
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        placeActionButtons(contactButtons)

        presentationObservation = dependencies.presentationContext.observe { [weak self] data in
            self?.apply(data)
        }
    }

    private func apply(_ data: PresentationData) {
        navigationItem.title = data.strings.newChatTitle
        view.backgroundColor = data.theme.colors.background

        for (id, button) in zip(DemoChats.ids, contactButtons) {
            button.apply(title: data.strings.profileTitle(id), theme: data.theme)
        }
    }
}
